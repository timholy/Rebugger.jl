# Core debugging logic.
# Hopefully someday much of this will be replaced by Gallium.

const VarnameType = Tuple{Vararg{Symbol}}
struct Stored
    method::Method
    varnames::VarnameType
    varvals
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
end
struct SignatureError  <: Exception
    method::Method
end
struct StepException   <: Exception
    msg::String
end

### Stacktraces

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
    local trace
    errored = true
    try
        eval_noinfo(mod, command)
        errored = false
    catch
        trace = stacktrace(catch_backtrace())
    end
    errored || error("$command did not throw an error")
    # Truncate the stacktrace at eval_noinfo & check whether the same method appears in multiple slots
    calledmethods = Method[]
    for (i, t) in enumerate(trace)
        if t.func == :eval_noinfo
            resize!(trace, i-1)
            break
        end
        t.func ∈ notrace && continue
        startswith(String(t.func), '#') && continue # skip generated methods
        if !has_no_linfo(t)
            m = t.linfo.def
            @assert m isa Method
            push!(calledmethods, m)
        end
    end
    Base.show_backtrace(stderr, trace)
    print(stderr, '\n')
    length(unique(calledmethods)) == length(calledmethods) || @error "the same method appeared twice, not supported. Try stepping into the command."
    capture_stacktrace!(UUID[], calledmethods) do
        eval_noinfo(mod, command)
    end
end
capture_stacktrace(command::Expr) = capture_stacktrace(Main, command)

function capture_stacktrace!(f::Function, uuids::Vector, calledmethods::Vector)
    if isempty(calledmethods)
        # We've finished modifying all the methods, time to run the command
        try
            f()
            @warn "traced method did not throw an error"
        catch
        end
        return
    end
    method = calledmethods[end]
    def = get_def(method)
    if def != nothing
        push!(uuids, method_capture_from_callee(method, def; overwrite=true))
    end
    # Recurse up the stack until we get to the top...
    pop!(calledmethods)
    capture_stacktrace!(f, uuids, calledmethods)
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
        err isa StopException || rethrow(err)
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
    callexpr.head == :call || throw(Meta.ParseError("point must be at a call expression, got $callexpr"))
    fname, args = callexpr.args[1], callexpr.args[2:end]
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
    sigr, body = get_signature(def), unquote(funcdef_body(def))
    sigr == nothing && throw(SignatureError(method))
    sigex = convert(Expr, sigr)
    methname, argnames, kwnames, paramnames = signature_names(sigex)
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
    storeexpr = :(Main.Rebugger.stored[$uuid] = Main.Rebugger.Stored($method, ($(qallnames...),), Main.Rebugger.safe_deepcopy($(allnames...))))
    capture_body = overwrite ? quote
        $storeexpr
        $body
    end : quote
        $storeexpr
        throw(Main.Rebugger.StopException())
    end
    capture_name = _gensym(methname)
    mod = method.module
    capture_function = Expr(:function, overwrite ? sigex : rename_method(sigex, capture_name, callerobj), capture_body)
    storefunc[uuid] = Core.eval(mod, capture_function)
    storemap[(method, overwrite)] = uuid
    return uuid
end
function method_capture_from_callee(method; kwargs...)
    # Could use a default arg above but this generates a more understandable error message
    def = get_def(method)
    def == nothing && throw(DefMissing(method))
    method_capture_from_callee(method, def; kwargs...)
end

function generate_let_command(method::Method, uuid::UUID)
    s = stored[uuid]
    @assert method == s.method
    argstring = '(' * join(s.varnames, ", ") * (length(s.varnames)==1 ? ",)" : ')')
    body = convert(Expr, striplines!(deepcopy(funcdef_body(get_def(method)))))
    return """
        @eval $(method.module) let $argstring = Main.Rebugger.getstored(\"$uuid\")
        $body
        end"""
end
function generate_let_command(uuid::UUID)
    s = stored[uuid]
    generate_let_command(s.method, uuid)
end

getstored(uuidstr::AbstractString) = safe_deepcopy(Main.Rebugger.stored[UUID(uuidstr)].varvals...)

kwstasher(; kwargs...) = kwargs

### Utilities

"""
    fname, argnames, kwnames, parameternames = signature_names(sigex::Expr)

Return the function name `fname` and names given to its arguments, keyword arguments,
and parameters, as specified by the method signature-expression `sigex`.

# Examples

```jldoctest; setup=:(using Rebugger)
julia> Rebugger.signature_names(:(complexargs(w::Ref{A}, @nospecialize(x::Integer), y, z::String=""; kwarg::Bool=false, kw2::String="", kwargs...) where A <: AbstractArray{T,N} where {T,N}))
(:complexargs, (:w, :x, :y, :z), (:kwarg, :kw2, :kwargs), (:A, :T, :N))
```
"""
function signature_names(sigex::ExLike)
    # TODO: add parameter names
    argname(s::Symbol) = s
    function argname(ex::ExLike)
        if ex.head == :(...) && length(ex.args) == 1
            # varargs function
            ex = ex.args[1]
            ex isa Symbol && return ex
        end
        ex.head == :macrocall && return argname(ex.args[3])  # @nospecialize
        ex.head == :kw && return argname(ex.args[1])  # default arguments
        ex.head == :(::) || throw(ArgumentError(string("expected :(::) expression, got ", ex)))
        arg = ex.args[1]
        if isa(arg, Expr) && arg.head == :curly && arg.args[1] == :Type
            arg = arg.args[2]
        end
        return arg
    end
    paramname(s::Symbol) = s
    function paramname(ex::ExLike)
        ex.head == :(<:) && return paramname(ex.args[1])
        throw(ArgumentError(string("expected parameter expression, got ", ex)))
    end

    kwnames, parameternames = (), ()
    while sigex.head == :where
        parameternames = (paramname.(sigex.args[2:end])..., parameternames...)
        sigex = sigex.args[1]
    end
    name = sigex.args[1]
    offset = 1
    if length(sigex.args) > 1 && isa(sigex.args[2], ExLike) && sigex.args[2].head == :parameters
        # keyword arguments
        kwnames = tuple(argname.(sigex.args[2].args)...)
        offset += 1
    end

    return sigex.args[1], tuple(argname.(sigex.args[offset+1:end])...), kwnames, parameternames
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

has_no_linfo(sf::Base.StackFrame) = !isa(sf.linfo, Core.MethodInstance)

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

const notrace = (:error, :throw)
