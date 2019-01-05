# Core debugging logic.
# Hopefully someday much of this will be replaced by Gallium.

const VarnameType = Tuple{Vararg{Union{Symbol,Expr}}}  # Expr covers `foo(x, (a,b), y)` destructured-tuple signatures
struct Stored
    method::Method
    varnames::VarnameType
    varvals

    function Stored(m, names, vals)
        new(m, names, safe_deepcopy(vals...))
    end
end

const stashed     = Ref{Any}(nothing)
const stored      = Dict{UUID,Stored}()              # UUID => store data
const storefunc   = Dict{UUID,Function}()            # UUID => function that puts inputs into `stored`
const storemap    = Dict{Tuple{Method,Bool},UUID}()  # (method, overwrite) => UUID

struct StopException   <: Exception end
struct StashingFailed  <: Exception end   # stashing saves the function and arguments from the caller (transient)
struct StorageFailed   <: Exception end   # storage puts callee values into `stored` (lasts until `stored` is cleared)
struct DefMissing      <: Exception
    method::Method
    exception
end
struct SignatureError  <: Exception
    method::Method
end
struct StepException   <: Exception
    msg::String
end
struct EvalException   <: Exception
    exprstring
    exception
end

const base_prefix = '.' * Base.Filesystem.path_separator

"""
    Rebugger.clear()

Clear internal data. This deletes storage associated with stored variables, but also
forces regeneration of capture methods, which can be handy while debugging Rebugger itself.
"""
function clear()
    stashed[] = nothing
    empty!(stored)
    empty!(storefunc)
    empty!(storemap)
    nothing
end

### Stacktraces

"""
    r = linerange(expr, offset=0)

Compute the range of lines occupied by `expr`.
Returns `nothing` if no line statements can be found.
"""
function linerange(def::ExLike, offset=0)
    start, haslinestart = findline(def, identity)
    stop, haslinestop  = findline(def, Iterators.reverse)
    (haslinestart & haslinestop) && return (start+offset):(stop+offset)
    return nothing
end

function findline(ex, order)
    ex.head == :line && return ex.args[1], true
    for a in order(ex.args)
        a isa LineNumberNode && return a.line, true
        if a isa ExLike
            ln, hasline = findline(a, order)
            hasline && return ln, true
        end
    end
    return 0, false
end

"""
    usrtrace, defs = pregenerated_stacktrace(trace, topname=:capture_stacktrace)

Generate a list of methods `usrtrace` and their corresponding definition-expressions `defs`
from a stacktrace.
Not all methods can be looked up, but this attempts to resolve, e.g., keyword-handling methods
and so on.
"""
function pregenerated_stacktrace(trace; topname = :capture_stacktrace)
    usrtrace, defs = Method[], RelocatableExpr[]
    methodsused = Set{Method}()

    # When the method can't be found directly in the tables,
    # look it up by fie and line number
    function add_by_file_line(defmap, line)
        for (def, info) in defmap
            info == nothing && continue
            sigts, offset = info
            r = linerange(def, offset)
            r == nothing && continue
            if line ∈ r
                mths = Base._methods_by_ftype(last(sigts), -1, typemax(UInt))
                m = mths[end][3]    # the last method is the least specific that matches the signature (which would be more specific if it were used)
                if m ∉ methodsused
                    push!(defs, def)
                    push!(usrtrace, m)
                    push!(methodsused, m)
                    return true
                end
            end
        end
        return false
    end
    function add_by_file_line(pkgdata, file, line)
        fi = get(pkgdata.fileinfos, file, nothing)
        if fi !== nothing
            Revise.maybe_parse_from_cache!(pkgdata, file)
            for (mod, fmm) in fi.fm
                add_by_file_line(fmm.defmap, line) && return true
            end
        end
        return false
    end

    for (i, sf) in enumerate(trace)
        sf.func == topname && break  # truncate at the chosen spot
        sf.func ∈ notrace && continue
        mi = sf.linfo
        file = String(sf.file)
        if mi isa Core.MethodInstance
            method = mi.def
            def = nothing
            if String(method.name)[1] != '#'   # if not a keyword/default arg method
                try
                    def = Revise.get_def(method)
                catch
                    continue
                end
            end
            if def === nothing
                # This may be a generated method, perhaps it's a keyword function handler
                # Look for it by line number
                local id
                try
                    id = Revise.get_tracked_id(method.module)
                catch
                    # Methods from Core.Compiler cause errors on Julia binaries
                    continue
                end
                id === nothing && continue
                pkgdata = Revise.pkgdatas[id]
                cfile = get(Revise.src_file_key, file, file)
                rpath = relpath(cfile, pkgdata)
                haskey(pkgdata.fileinfos, rpath) || continue
                Revise.maybe_parse_from_cache!(pkgdata, rpath)
                fi = get(pkgdata.fileinfos, rpath, nothing)
                if fi !== nothing
                    add_by_file_line(fi.fm[method.module].defmap, sf)
                end
            else
                method ∈ methodsused && continue
                def isa ExLike || continue
                push!(defs, def)
                push!(usrtrace, method)
            end
        else
            # This method was inlined and hence linfo was not available
            # Try to find it
            if startswith(file, base_prefix)
                # This is a file in Base or Core
                file = relpath(file, base_prefix)
                id = Revise.get_tracked_id(Base)
                pkgdata = Revise.pkgdatas[id]
                if haskey(pkgdata.fileinfos, file)
                    add_by_file_line(pkgdata, file, sf.line) && continue
                elseif startswith(file, "compiler")
                    try
                        id = Revise.get_tracked_id(Core.Compiler)
                    catch
                        # On Julia binaries Core.Compiler is not available
                        continue
                    end
                    pkgdata = Revise.pkgdatas[id]
                    add_by_file_line(pkgdata, relpath(file, pkgdata), sf.line) && continue
                end
            end
            # Try all loaded packages
            for (id, pkgdata) in Revise.pkgdatas
                rpath = relpath(file, pkgdata)
                add_by_file_line(pkgdata, rpath, sf.line) && break
            end
        end
    end
    return usrtrace, defs
end

"""
    uuids = capture_stacktrace(mod, command)

Execute `command` in module `mod`. `command` must throw an error.
Then instrument the methods in the stacktrace so that their input
variables are stored in `Rebugger.stored`.
After storing the inputs, restore the original methods.

Since this requires two `eval`s of `command`, usage should be limited to
deterministic expressions that always result in the same call chain.
"""
function capture_stacktrace(mod::Module, command::Expr)
    errored = true
    trace = try
        Core.eval(mod, command)
        errored = false
    catch
        stacktrace(catch_backtrace())
    end
    errored || error("$command did not throw an error")
    usrtrace, defs = pregenerated_stacktrace(trace)
    isempty(usrtrace) && error("failed to capture any elements of the stacktrace")
    println(stderr, "Captured elements of stacktrace:")
    show(stderr, MIME("text/plain"), usrtrace)
    length(unique(usrtrace)) == length(usrtrace) || @error "the same method appeared twice, not supported. Try stepping into the command."
    uuids = UUID[]
    capture_stacktrace!(uuids, usrtrace, defs) do
        Core.eval(mod, command)
    end
    uuids
end
capture_stacktrace(command::Expr) = capture_stacktrace(Main, command)

function capture_stacktrace!(f::Function, uuids::Vector, usrtrace, defs)
    if isempty(usrtrace)
        # We've finished modifying all the methods, time to run the command
        try
            f()
            @warn "traced method did not throw an error"
        catch
        end
        return
    end
    method, def = usrtrace[end], defs[end]
    if def != nothing
        push!(uuids, method_capture_from_callee(method, def; overwrite=true))
    end
    # Recurse up the stack until we get to the top...
    pop!(usrtrace)
    pop!(defs)
    capture_stacktrace!(f, uuids, usrtrace, defs)
    # ...after which it will call the erroring function and come back here.
    # Having come back, restore the original definition
    if def != nothing
        eval_noinfo(method.module, def)  # unfortunately this doesn't restore the original method as a viable key to storemap
    end
    return uuids
end

### Stepping

function stepin(io)
    @assert Rebugger.stashed[] === nothing
    # Step 1: rewrite the command to stash the call function and its arguments.
    prepare_caller_capture!(io)
    capexpr, stop = Meta.parse(content(io), 1)
    try
        Core.eval(Main, capexpr)
        throw(StashingFailed())
    catch err
        err isa StashingFailed && rethrow(err)
        if !(err isa StopException)
            throw(EvalException(content(io), err))
        end
    end
    f, args, kwargs = Rebugger.stashed[]
    Rebugger.stashed[] = nothing
    # Step 2: determine which method is called, and if need be create a function
    # that captures all of the callee's inputs. (This allows us to capture default arguments,
    # keyword arguments, and type parameters.)
    method = which(f, Base.typesof(args...))
    uuid = get(storemap, (method, false), nothing)
    if uuid === nothing
        uuid = method_capture_from_callee(method; overwrite=false)
    end
    # Step 3: execute the command to store the inputs.
    fcapture = storefunc[uuid]
    tv, decls = Base.arg_decl_parts(method)
    if !isempty(decls[1][1])
        # This is a call-overloaded method, prepend the calling object
        args = (f, args...)
    end
    try
        Base.invokelatest(fcapture, args...; kwargs...)
        throw(StorageFailed())   # this should never happen
    catch err
        err isa StopException || rethrow(err)
    end
    return uuid, generate_let_command(method, uuid)
end

"""
    callexpr = prepare_caller_capture!(io)

Given a buffer `io` representing a string and "point" (the seek position) set at a call expression,
replace the call with one that stashes the function and arguments of the call.

For example, if `io` has contents

    <some code>
    if x > 0.5
        ^fcomplex(x, 2; kw1=1.1)
        <more code>

where in the above `^` indicates `position(s)` ("point"), rewrite this as

    <some code>
    if x > 0.5
        Main.Rebugger.stashed[] = (fcomplex, (x, 2), (kw1=1.1,))
        throw(Rebugger.StopException())
        <more code>

(Keyword arguments do not affect dispatch and hence are not stashed.)
Consequently, if this is `eval`ed and execution reaches "^", it causes the arguments
of the call to be placed in `Rebugger.stashed`.

`callexpr` is the original (unmodified) expression specifying the call, i.e.,
`fcomplex(x, 2; kw1=1.1)` in this case.

This does the buffer-preparation for *caller* capture.
For *callee* capture, see [`method_capture_from_callee`](@ref),
and [`stepin`](@ref) which puts these two together.
"""
function prepare_caller_capture!(io)  # for testing, needs to work on a normal IO object
    start = position(io)
    callstring = content(io, start=>bufend(io))
    callexpr, len = Meta.parse(callstring, 1; raise=false)
    callexpr == nothing && throw(StepException("Got empty expression from $callstring"))
    isa(callexpr, Expr) || throw(StepException("Rebugger can only step into expressions, got $callexpr"))
    if callexpr.head == :error
        iend = len
        for i = 1:2
            iend = prevind(callstring, iend)
        end
        callstring = callstring[1:iend]
        callexpr, len = Meta.parse(callstring, 1)
    end
    if callexpr.head == :tuple && !(startswith(callstring, "tuple") || startswith(callstring, "("))
        # An expression like foo(bar(x)..., 1) where point is positioned at bar
        callexpr = callexpr.args[1]
    end
    if callexpr.head == :ref
        callexpr = Expr(:call, :getindex, callexpr.args...)
    elseif callexpr.head == :(=) && isa(callexpr.args[1], Expr) && callexpr.args[1].head == :ref
        ref, val = callexpr.args
        callexpr = Expr(:call, :setindex!, ref.args[1], val, ref.args[2:end]...)
    elseif (callexpr.head == :&& || callexpr.head == :||) && isa(callexpr.args[1], Expr)
        callexpr = callexpr.args[1]
    elseif callexpr.head == :...
        callexpr = callexpr.args[1]
    end
    # Must be a call or broadcast
    ((callexpr.head == :call) | (callexpr.head == :.)) || throw(Meta.ParseError("point must be at a call expression, got $callexpr"))
    if callexpr.head == :call
        fname, args = callexpr.args[1], callexpr.args[2:end]
    else
        fname, args = :broadcast, [callexpr.args[1], callexpr.args[2].args...]
    end
    # In the edited callstring separate any kwargs now. They don't affect dispatch.
    kwargs = []
    if length(args) >= 1 && isa(args[1], Expr) && args[1].head == :parameters
        # foo(x; kw1=1, ...) syntax    (with the semicolon)
        append!(kwargs, popfirst!(args).args)
    end
    while !isempty(args) && isa(args[end], Expr) && args[end].head == :kw
        # foo(x, kw1=1, ...) syntax    (with a comma, no semicolon)
        push!(kwargs, pop!(args))
    end
    captureexpr = quote
        Main.Rebugger.stashed[] = ($fname, (($(args...)),), Main.Rebugger.kwstasher(; $(kwargs...)))
        throw(StopException())
    end
    # Now insert this in place of the marked call
    # Unfortunately we have to convert to a string and there are scoping issues
    capturestr = string(captureexpr, '\n')
    regexunscoped = r"(?<!\.)StopException"
    capturestr = replace(capturestr, regexunscoped=>(s->"Rebugger."*s))
    regexscoped   = r"(?<!\.)Rebugger\.StopException"
    capturestr = replace(capturestr, regexscoped=>(s->"Main."*s))
    edit_splice!(io, start=>start+len-1, capturestr)
    return callexpr
end

"""
    uuid = method_capture_from_callee(method; overwrite::Bool=false)

Create a version of `method` that stores its inputs in `Main.Rebugger.stored`.
For a method

    function fcomplex(x::A, y=1, z=""; kw1=3.2) where A<:AbstractArray{T} where T
        <body>
    end

if `overwrite=false`, this generates a new method

    function hidden_fcomplex(x::A, y=1, z=""; kw1=3.2) where A<:AbstractArray{T} where T
        Main.Rebugger.stored[uuid] = Main.Rebugger.Stored(fcomplex, (:x, :y, :z, :kw1, :A, :T), deepcopy((x, y, z, kw1, A, T)))
        throw(StopException())
    end

(If a `uuid` already exists for `method` from a previous call to `method_capture_from_callee`,
it will simply be returned.)

With `overwrite=true`, there are two differences:

- it replaces `fcomplex` rather than defining `hidden_fcomplex`
- rather than throwing `StopException`, it re-inserts `<body>` after the line performing storage

The returned `uuid` can be used for accessing the stored data.
"""
function method_capture_from_callee(method, def; overwrite::Bool=false)
    uuid = get(storemap, (method, overwrite), nothing)
    uuid != nothing && return uuid
    def = pop_annotations(def)
    sigr, body = get_signature(def), unquote(funcdef_body(def))
    sigr == nothing && throw(SignatureError(method))
    sigex = convert(Expr, sigr)
    if sigex.head == :(::)
        sigex = sigex.args[1]  # return type declaration
    end
    methname, argnames, kwnames, paramnames = signature_names!(sigex)
    # Check for call-overloading method, e.g., (obj::ObjType)(x, y...) = <body>
    callerobj = nothing
    if methname isa Expr && methname.head == :(::)
        @assert length(methname.args) == 2
        callerobj = methname
        argnames = (methname.args[1], argnames...)
        methname = methname.args[2]
        if methname isa Expr
            if methname.head == :curly
                methname = methname.args[1]
            else
                dump(methname)
                error("unexpected call-overloading type")
            end
        end
    end
    allnames = (argnames..., kwnames..., paramnames...)
    qallnames = QuoteNode.(allnames)
    uuid = uuid1()
    uuidstr = string(uuid)
    storeexpr = :(Main.Rebugger.setstored!($uuidstr=>Main.Rebugger.Stored($method, ($(qallnames...),), ($(allnames...),)) ) )
    capture_body = overwrite ? quote
        $storeexpr
        $body
    end : quote
        $storeexpr
        throw(Main.Rebugger.StopException())
    end
    capture_name = try
        _gensym(methname)
    catch
        nothing
    end
    capture_name == nothing && (dump(methname); dump(sigex); error("couldn't gensym"))
    # capture_name = _gensym(methname)
    mod = method.module
    capture_function = Expr(:function, overwrite ? sigex : rename_method(sigex, capture_name, callerobj), capture_body)
    result = Core.eval(mod, capture_function)
    if !overwrite
        storefunc[uuid] = result
    end
    storemap[(method, overwrite)] = uuid
    return uuid
end
function method_capture_from_callee(method; kwargs...)
    # Could use a default arg above but this generates a more understandable error message
    local def
    try
        def = get_def(method; modified_files=typeof(Revise.revision_queue)())
    catch err
        throw(DefMissing(method, err))
    end
    def == nothing && throw(DefMissing(method, nothing))
    method_capture_from_callee(method, def; kwargs...)
end

function generate_let_command(method::Method, uuid::UUID)
    s = stored[uuid]
    @assert method == s.method
    argstring = '(' * join(s.varnames, ", ") * (length(s.varnames)==1 ? ",)" : ')')
    body = convert(Expr, striplines!(copy(funcdef_body(get_def(method; modified_files=String[])))))
    return """
        @eval $(method.module) let $argstring = Main.Rebugger.getstored(\"$uuid\")
        $body
        end"""
end
function generate_let_command(uuid::UUID)
    s = stored[uuid]
    generate_let_command(s.method, uuid)
end

"""
    args_and_types = Rebugger.getstored(uuid)

Retrieve the values of stored arguments and type-parameters from the store specified
`uuid`. This makes a copy of values, so as to be safe for repeated execution of methods
that modify their inputs.
"""
getstored(uuidstr::AbstractString) = safe_deepcopy(Main.Rebugger.stored[UUID(uuidstr)].varvals...)

function setstored!(p::Pair{S,Stored}) where S<:AbstractString
    uuidstr, val = p.first, p.second
    Main.Rebugger.stored[UUID(uuidstr)] = val
end

kwstasher(; kwargs...) = kwargs

### Utilities

"""
    fname, argnames, kwnames, parameternames = signature_names!(sigex::Expr)

Return the function name `fname` and names given to its arguments, keyword arguments,
and parameters, as specified by the method signature-expression `sigex`.

`sigex` will be modified if some of the arguments are unnamed.


# Examples

```jldoctest; setup=:(using Rebugger)
julia> Rebugger.signature_names!(:(complexargs(w::Ref{A}, @nospecialize(x::Integer), y, z::String=""; kwarg::Bool=false, kw2::String="", kwargs...) where A <: AbstractArray{T,N} where {T,N}))
(:complexargs, (:w, :x, :y, :z), (:kwarg, :kw2, :kwargs), (:A, :T, :N))

julia> ex = :(myzero(::Float64));     # unnamed argument

julia> Rebugger.signature_names!(ex)
(:myzero, (:__Float64_1,), (), ())

julia> ex
:(myzero(__Float64_1::Float64))
```
"""
function signature_names!(sigex::ExLike)
    # TODO: add parameter names
    argname(s::Symbol) = s
    function argname(ex::ExLike)
        if ex.head == :(...) && length(ex.args) == 1
            # varargs function
            ex = ex.args[1]
            ex isa Symbol && return ex
        end
        (ex.head == :macrocall || ex.head == :meta) && return argname(ex.args[end])  # @nospecialize
        ex.head == :kw && return argname(ex.args[1])  # default arguments
        ex.head == :tuple && return ex    # tuple-destructuring argument
        ex.head == :(::) || throw(ArgumentError(string("expected :(::) expression, got ", ex)))
        arg = ex.args[1]
        if length(ex.args) == 1 && (arg isa Symbol)
            # This argument has a type but no name
            return arg, true
        end
        if isa(arg, Expr) && arg.head == :curly
            if arg.args[1] == :Type
                # Argument of the form ::Type{T}
                return arg.args[2], false
            elseif arg.args[1] == :NamedTuple
                return :NamedTuple, true, arg
            end
        end
        return arg
    end
    paramname(s::Symbol) = s
    function paramname(ex::ExLike)
        ex.head == :(<:) && return paramname(ex.args[1])
        throw(ArgumentError(string("expected parameter expression, got ", ex)))
    end

    kwnames, parameternames = (), []
    while sigex.head == :where
        parameternames = [paramname.(sigex.args[2:end])..., parameternames...]
        sigex = sigex.args[1]
    end
    name = sigex.args[1]
    offset = 1
    if length(sigex.args) > 1 && isa(sigex.args[2], ExLike) && sigex.args[2].head == :parameters
        # keyword arguments
        kwnames = tuple(argname.(sigex.args[2].args)...)
        offset += 1
    end
    # Argnames. For any unnamed arguments we have to generate a name.
    empty!(usdict)
    argnames = Union{Symbol,Expr}[]
    for i = offset+1:length(sigex.args)
        arg = sigex.args[i]
        retname = argname(arg)
        if retname isa Tuple
            should_gen = retname[2]
            if should_gen
                # This argument is missing a real name
                argt = length(retname) == 3 ? retname[3] : retname[1]
                name = genunderscored(retname[1])
                sigex.args[i] = :($name::$argt)
            else
                # This is a ::Type{T} argument. We should remove this from the list of parameters
                name = retname[1]
                parameternames = filter(!isequal(name), parameternames)
            end
            retname = name
        end
        push!(argnames, retname)
    end

    return sigex.args[1], tuple(argnames...), kwnames, tuple(parameternames...)
end

function rename_method!(ex::ExLike, name::Symbol, callerobj)
    sig = ex.head ∈ (:call, :where) ? ex : get_signature(ex)
    while isa(sig, ExLike) && sig.head == :where
        sig = sig.args[1]
    end
    sig.head == :call || (dump(ex); throw(ArgumentError(string("expected call expression, got ", ex))))
    sig.args[1] = name
    if callerobj != nothing
        # Call overloading, add an argument
        sig.args = [sig.args[1]; callerobj; sig.args[2:end]]
    end
    return ex
end
rename_method(ex::ExLike, name::Symbol, callerobj) = rename_method!(copy(ex), name, callerobj)

function pop_annotations(def::ExLike)
    while Revise.is_trivial_block_wrapper(def) || (
            def isa ExLike && def.head == :macrocall && Revise.is_poppable_macro(def.args[1]))
        def = def.args[end]
    end
    def
end

# Use to re-evaluate an expression without leaving "breadcrumbs" about where
# the eval is coming from. This is used below to prevent the re-evaluaton of an
# original method from being attributed to Rebugger itself in future backtraces.
eval_noinfo(mod::Module, ex::Expr) = ccall(:jl_toplevel_eval, Any, (Any, Any), mod, ex)
eval_noinfo(mod::Module, rex::RelocatableExpr) = eval_noinfo(mod, convert(Expr, rex))

function unquote(ex::Expr)
    if ex.head == :quote
        return Expr(:block, ex.args...)
    end
    ex
end
unquote(rex::RelocatableExpr) = unquote(convert(Expr, rex))

_gensym(sym::Symbol) = gensym(sym)
_gensym(q::QuoteNode) = _gensym(q.value)
_gensym(ex::Expr) = (@assert ex.head == :. && length(ex.args) == 2; _gensym(ex.args[2]))

const usdict = Dict{Symbol,Int}()
function genunderscored(sym::Symbol)
    n = get(usdict, sym, 0) + 1
    usdict[sym] = n
    return Symbol("__"*String(sym)*'_'*string(n))
end

const notrace = (:error, :throw)
