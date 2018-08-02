# Core debugging logic. It abuses the poor compiler terribly.
# Hopefully someday much of this will be replaced by Gallium.

const VarnameType = Tuple{Vararg{Symbol}}
const stack       = Tuple{Method,VarnameType,Any}[]
const stackid     = Ref(randstring(8))
const stackcmd    = String[]
const stashed     = Ref{Any}(nothing)

struct StopException   <: Exception end
struct StashingFailed  <: Exception end   # stashing saves the function and arguments from the caller (transient)
struct StorageFailed   <: Exception end   # storage puts callee values on the stack (lasts until the stack is cleared)
struct DefMissing      <: Exception
    method::Method
end
struct SignatureError  <: Exception
    method::Method
end

### Stacktraces

"""
    capture_stacktrace(mod, command)

Execute `command` in module `mod`. `command` must throw an error.
Then instrument the methods in the stacktrace so that their input
variables are stored in `Rebugger.stack`.
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
    capture_stacktrace!(reverse!(calledmethods)) do
        eval_noinfo(mod, command)
    end
    return nothing
end
capture_stacktrace(command::Expr) = capture_stacktrace(Main, command)

function capture_stacktrace!(f::Function, calledmethods::Vector)
    index = length(calledmethods)
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
        # Now modify `def` to insert into slot `index` (don't throw an error)
        # and eval it in the appropriate module
        method_capture_from_callee(method, def, index; trunc=false)
    end
    # Recurse up the stack until we get to the top...
    pop!(calledmethods)
    capture_stacktrace!(f, calledmethods)
    # ...after which it will call the erroring function and come back here.
    # Having come back, restore the original definition
    if def != nothing
        eval_noinfo(method.module, def)
    end
end

### Stepping

function stepin!(io, index, meta="")
    @assert Rebugger.stashed[] === nothing
    command = content(io)
    callexpr, _ = Meta.parse(command, 1)  # we'd prefer to call the "short" expression but it may lack scope
    prepare_caller_capture!(io)
    capexpr, stop = Meta.parse(content(io), 1)
    try
        Core.eval(Main, capexpr)
        throw(StashingFailed())
    catch err
        err isa StopException || rethrow(err)
    end
    f, args = Rebugger.stashed[]
    Rebugger.stashed[] = nothing
    method = which(f, Base.typesof(args...))
    capture_from_callee(method, callexpr, index)
    return generate_let_command(index, meta)
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
        Main.Rebugger.stashed[] = (fcomplex, (x, 2))
        throw(Rebugger.StopException())
        <more code>

(Keyword arguments do not affect dispatch and hence are not stashed.)
Consequently, if this is `eval`ed and execution reaches "^", it causes the arguments
of the call to be stored in `Rebugger.stashed`.

`callexpr` is the original (unmodified) expression specifying the call, i.e.,
`fcomplex(x, 2; kw1=1.1)` in this case.

This does the buffer-preparation for *caller* capture.
For *callee* capture, see [`method_capture_from_callee`](@ref),
and [`stepin!`](@ref) which puts these two together.
"""
function prepare_caller_capture!(io)  # for testing, needs to work on a normal IO object
    start = position(io)
    callstring = content(io, start=>bufend(io))
    callexpr, len = Meta.parse(callstring, 1)
    (isa(callexpr, Expr) && callexpr.head == :call) || throw(Meta.ParseError("point must be at a call expression, got $callexpr"))
    fname, args = callexpr.args[1], callexpr.args[2:end]
    # In the edited callstring we can eliminate any kwargs, because they don't affect dispatch
    # (all we want to do is figure out which method gets called)
    if length(args) >= 1 && isa(args[1], Expr) && args[1].head == :parameters
        popfirst!(args)
    end
    while !isempty(args) && isa(args[end], Expr) && args[end].head == :kw
        pop!(args)
    end
    captureexpr = quote
        Main.Rebugger.stashed[] = ($fname, (($(args...)),))
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
    capture_from_callee(method::Method, callexpr, index)

Given an expression `callexpr` that will resuling in calling `method` (not necessarily directly),
store the method, its argument names, and input values to `Rebugger.stack[index]`.

`callexpr` will then be `eval`ed in `Main`; all the variables needed by `callexpr`
must already be defined.

Finally, the method will be restored to its original definition.

This does *callee* capture using [`method_capture_from_callee`](@ref).
For *caller* capture, see [`prepare_caller_capture!`](@ref).
"""
function capture_from_callee(method::Method, callexpr, index::Integer)
    def = get_def(method)
    def == nothing && throw(DefMissing(method))
    # Create the input-capturing callee method and then call it using the original
    # line that was on the REPL
    method_capture_from_callee(method, def, index; trunc=true)
    try
        # Now that we've modified the method, do not exit without restoring it
        try
            # Eval `callexpr` in Main. We expect a StopException, so catch it.
            eval_noinfo(Main, callexpr)
            throw(StorageFailed())   # if we got here, `method` was never called
        catch err
            err isa StopException || rethrow(err)
        end
    finally
        # Restore the original method
        eval_noinfo(method.module, def)
    end
    return Rebugger.stack[index]
end

"""
    method_capture_from_callee(method, def, index; trunc::Bool=false)

Redefine `method` so that it stores its inputs in `Main.Rebugger.stack[index]`.
For a method

    function fcomplex(x::A, y=1, z=""; kw1=3.2) where A<:AbstractArray{T} where T
        <body>
    end

generate a new method

    function fcomplex(x::A, y=1, z=""; kw1=3.2) where A<:AbstractArray{T} where T
        Main.Rebugger.stack[index] = (fcomplex, (:x, :y, :z, :kw1, :A, :T), deepcopy((x, y, z, kw1, A, T)))
        <body>
    end

or, if `trunc` is true, replace the body with `throw(StopException())`.

`def` is the (unlowered) expression that defines the method.
"""
function method_capture_from_callee(method, def, index; trunc::Bool=false)
    sigr, body = get_signature(def), unquote(funcdef_body(def))
    sigr == nothing && throw(SignatureError(method))
    sig = convert(Expr, sigr)
    methname, argnames, kwnames, paramnames = signature_names(sig)
    allnames = (argnames..., kwnames..., paramnames...)
    qallnames = QuoteNode.(allnames)
    storeexpr = :(Main.Rebugger.stack[$index] = ($method, ($(qallnames...),), Main.Rebugger.safe_deepcopy($(allnames...))))
    capture_body = trunc ? quote
        $storeexpr
        throw(Main.Rebugger.StopException())
    end : quote
        $storeexpr
        $body
    end
    capture_function = Expr(:function, sig, capture_body)
    if index > length(stack)
        resizestack(index)
    end
    mod = method.module
    eval_noinfo(mod, capture_function)
end

function generate_let_command(index::Integer, meta = "")
    method, varnames, varvals = stack[index]
    argstring = '(' * join(varnames, ", ") * (length(varnames)==1 ? ",)" : ')')
    body = convert(Expr, striplines!(deepcopy(funcdef_body(get_def(method)))))
    return """
        @eval $(method.module) let $argstring = Main.Rebugger.getstack($index)$meta
        $body
        end"""
end

getstack(index) = safe_deepcopy(Main.Rebugger.stack[index][3]...)


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

safe_deepcopy(a, args...) = (_deepcopy(a), safe_deepcopy(args...)...)
safe_deepcopy() = ()

_deepcopy(a) = deepcopy(a)
_deepcopy(a::Module) = a

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

const notrace = (:error, :throw)
