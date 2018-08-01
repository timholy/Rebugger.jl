module Rebugger

using REPL, Random
using REPL.LineEdit
using Revise
using Revise: ExLike, get_signature, funcdef_body, get_def

const VarnameType = Tuple{Vararg{Symbol}}
const stack       = Tuple{Method,VarnameType,Any}[]
const stackid     = Ref(randstring(8))
const stackcmd    = String[]
const error_stack = Tuple{Method,VarnameType,Any}[]
const stashed     = Ref{Any}(nothing)
const msgs        = []   # for debugging

struct StopException <: Exception end

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

"""
    capture_from_caller!(s)

Given a buffer `s` representing a string and "point" (the seek position) set at a call expression,
replace the call with one that stashes the function and arguments of the call.

For example, if `s` has contents

    <some code>
    if x > 0.5
        ^fcomplex(x; kw1=1.1)
        <more code>

where in the above `^` indicates `position(s)` ("point"), rewrite this as

    <some code>
    if x > 0.5
        Main.Rebugger.stashed[] = (fcomplex, (x,), (:kw1=>1.1,))
        throw(Rebugger.StopException())
        <more code>

Consequently, if this is `eval`ed and execution reaches "^", it causes the arguments
of the call to be stored in `Rebugger.stashed`.

This does the buffer-preparation for *caller* capture.
For *callee* capture, see [`method_capture_from_callee`](@ref),
and [`stepin!`](@ref) which puts these two together.
"""
function capture_from_caller!(s)  # for testing, needs to work on a normal IO object
    start = position(s)
    callstring = LineEdit.content(s)
    index, hasid = get_stack_index(callstring)
    index += 1
    if !hasid
        stackid[] = randstring(8)
    end
    expr, stop = Meta.parse(callstring, start+1; raise=false)
    (isa(expr, Expr) && expr.head == :call) || throw(Meta.ParseError("Point must be at a call expression, got $expr"))
    fname, args = expr.args[1], expr.args[2:end]
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
    capturestr = string(captureexpr)
    regexunscoped = r"(?<!\.)StopException"
    capturestr = replace(capturestr, regexunscoped=>(s->"Rebugger."*s))
    regexscoped   = r"(?<!\.)Rebugger\.StopException"
    capturestr = replace(capturestr, regexscoped=>(s->"Main."*s))
    LineEdit.edit_splice!(s, start=>stop-1, capturestr*"\n")
    return callstring, LineEdit.content(s), index
end

"""
    stepin!(s)

Given a buffer `s` representing a string and "point" (the seek position) set at a call expression,
replace the contents of the buffer with a `let` expression that wraps the *body* of the callee.

For example, if `s` has contents

    <some code>
    if x > 0.5
        ^fcomplex(x)
        <more code>

where in the above `^` indicates `position(s)` ("point"), and if the definition of `fcomplex` is

    function fcomplex(x::A, y=1, z=""; kw1=3.2) where A<:AbstractArray{T} where T
        <body>
    end

rewrite `s` so that its contents are

    @eval ModuleOf_fcomplex let (x, y, z, kw1, A, T) = Main.Rebugger.stack[index][3]
        <body>
    end

where `Rebugger.stack[index][3]` has been pre-loaded with the values that would have been
set when you called `fcomplex(x)` in `s` above.
This line can be edited and `eval`ed at the REPL to analyze or improve `fcomplex`,
or can be used for further `stepin!` calls.
"""
function stepin!(s)
    @assert(stashed[] == nothing)
    ## Stage 1 is "stashing". We do this simply to determine which method is called.
    callstring, stashstring, index = capture_from_caller!(s)
    callexpr, stashexpr = Meta.parse(callstring), Meta.parse(stashstring)
    try
        Core.eval(Main, stashexpr)
        @warn "evaluation did not reach the cursor position"
        @goto writeback
    catch err
        err isa StopException || rethrow(err)
    end
    ## Stage 2: retrieve the stashed values and get the correct method
    f, args = stashed[]
    method = which(f, Base.typesof(args...))
    stashed[] = nothing
    def = get_def(method)
    if def == nothing
        @warn "unable to step into $f"
        @goto writeback
    end
    ## Stage 3: storage, where the full callee arguments will be placed on Rebugger.stack
    # Create the input-capturing callee method and then call it using the original
    # line that was on the REPL
    method_capture_from_callee(method, def, index; trunc=true)
    try
        Core.eval(Main, callexpr)
        @warn "evaluation failed to store the inputs"
        @goto writeback
    catch err
        err isa StopException || rethrow(err)
    end
    resizestack(index)
    ## Stage 4: clean up and insert the new method body into the REPL
    # Restore the original method
    eval_noinfo(method.module, def)
    show_current_stackpos(s, index, -1)
    # Dump the method body to the REPL
    generate_let_command(s, index)
    return nothing

    @label writeback
    LineEdit.edit_clear(s)
    LineEdit.edit_insert(s, callstring)
    return nothing
end

function stepup!(s)
    callstring = LineEdit.content(s)
    index, hasid = get_stack_index(callstring)
    if hasid && index > 1
        letcommand = stackcmd[index-1]
        show_current_stackpos(s, index-1, 1)
        LineEdit.edit_insert(s, letcommand)
    end
    return nothing
end

function stepdown!(s)
    callstring = LineEdit.content(s)
    index, hasid = get_stack_index(callstring)
    if hasid && index < length(stack)
        letcommand = stackcmd[index+1]
        show_current_stackpos(s, index+1, -1)
        LineEdit.edit_insert(s, letcommand)
    end
    return nothing
end

function capture_stacktrace(s)
    push!(msgs, "stacktrace")
    resizestack(0)
    cmdstring = LineEdit.content(s)
    expr = Meta.parse(cmdstring)
    capture_stacktrace(expr)
    for index = 1:length(stack)
        stackcmd[index] = generate_let_command(index)
    end
    show_current_stackpos(s, length(stackcmd))
    LineEdit.edit_insert(s, stackcmd[end])
    return nothing
end


### Shared methods

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

`def` is the (unlowered) expression that defines `fcomplex`.
"""
function method_capture_from_callee(method, def, index; trunc::Bool=false)
    sigr, body = get_signature(def), unquote(funcdef_body(def))
    if sigr == nothing
        @warn "skipping capture: could not extract signature from $def"
        return nothing
    end
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

function generate_let_command(index)
    method, varnames, varvals = stack[index]
    argstring = '(' * join(varnames, ", ") * ')'
    body = convert(Expr, Revise.striplines!(deepcopy(funcdef_body(get_def(method)))))
    letcommand = """
        @eval $(method.module) let $argstring = Main.Rebugger.stack[$index][3]  # stackid $(stackid[])
        $body
        end"""
    end

function generate_let_command(s, index)
    letcommand = generate_let_command(index)
    stackcmd[index] = letcommand
    LineEdit.edit_clear(s)
    LineEdit.edit_insert(s, letcommand)
end

function show_current_stackpos(s, index, bonus=0)
    # Show stacktrace
    LineEdit.edit_clear(s)
    out_stream = s.current_mode.repl.t.out_stream
    print(out_stream, "\r\u1b[K")     # clear the line
    for _ in 1:index+bonus
        print(out_stream, "\r\u1b[K\u1b[A")   # move up while clearing line
    end
    for i = 1:index
        stackitem = stack[i]
        printstyled(out_stream, stackitem[1], '\n'; color=:light_magenta)
    end
    return nothing
end

### Key bindings

## REPL commands TODO:
## "\em" (meta-m): create REPL line that populates Main with arguments to current method
## "\eS" (meta-S): save version at REPL to file? (a little dangerous, perhaps make it configurable as to whether this is on)

const rebuggerkeys = Dict{Any,Any}(
    # F11. Note for `konsole` (KDE) users, F11 means "fullscreen". Turn off in Settings->Configure Shortcuts
    "\e[23~"   => (s, o...) -> stepin!(s),
    # Shift-F11
    "\e[23;2~" => (s, o...) -> stepup!(s),
    # Ctrl-F11
    "\e[23;5~" => (s, o...) -> stepdown!(s),
    # F5
    "\e[15~"   => (s, o...) -> capture_stacktrace(s),
)

function customize_keys(repl)
    repl.interface = REPL.setup_interface(repl; extra_repl_keymap = rebuggerkeys)
end


### Utilities

"""
    fname, argnames, kwnames, parameternames = signature_names(sigex::Expr)

Return the function name `fname` and names given to its arguments, keyword arguments,
and parameters, as specified by the method signature-expression `sigex`.

# Examples

```jldoctest; setup=:(using Revise)
julia> Revise.signature_names(:(complexargs(w::Ref{A}, @nospecialize(x::Integer), y, z::String=""; kwarg::Bool=false, kw2::String="", kwargs...) where A <: AbstractArray{T,N} where {T,N}))
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

function get_stack_index(callstring)
    index = length(stack)
    hasid = occursin("# stackid $(stackid[])", callstring)
    if hasid
        iend1 = findfirst(isequal('\n'), callstring)
        iend1 == nothing ? length(callstring) : iend1
        firstline = callstring[1:iend1]
        mindex = match(r"Main.Rebugger.stack\[(\d+)\]", firstline)
        index = parse(Int, mindex.captures[1])
    else
        index = 0
    end
    push!(msgs, (index, hasid))
    return index, hasid
end

function resizestack(index)
    resize!(stack, index)
    resize!(stackcmd, index)
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
eval_noinfo(mod::Module, rex::Revise.RelocatableExpr) = eval_noinfo(mod, convert(Expr, rex))

function unquote(ex::Expr)
    if ex.head == :quote
        return Expr(:block, ex.args...)
    end
    ex
end
unquote(rex::Revise.RelocatableExpr) = unquote(convert(Expr, rex))

const notrace = (:error, :throw)

end # module
