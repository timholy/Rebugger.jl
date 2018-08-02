const msgs        = []   # for debugging

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
function stepin!(s; metadata::Bool=true)
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
    metadata && show_current_stackpos(s, index, -1)
    # Dump the method body to the REPL
    generate_let_command(s, index; metadata=metadata)
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

# function showvalue(s)
#     callstring = LineEdit.content(s)
#     index, hasid = get_stack_index(callstring)
#     if hasid
#         p = position(s)
#     end
# end

function showinputs(s)
    callstring = LineEdit.content(s)
    index, hasid = get_stack_index(callstring)
    if hasid
        out_stream = s.current_mode.repl.t.out_stream
        sz = displaysize(out_stream)
        push!(msgs, sz)
        push!(msgs, s)
        stackentry = stack[index]
        nargs = length(stackentry[2])
        w = sz[2] ÷ nargs - 2
        io = IOBuffer()
        for (name, val) in zip(stackentry[2], stackentry[3])
            # print(out_stream, '\n')
            printf_maxsize(print, io, name, "=", val, ", "; maxlines=1, maxchars=w)
        end
        print(io, "\n\rjulia> ")
        s.current_mode.prompt = String(take!(io))
        LineEdit.refresh_line(s)
        s.current_mode.prompt = "julia> "
    end
    return nothing
end


function generate_let_command(s, index; metadata::Bool=true)
    letcommand = generate_let_command(index; metadata=metadata)
    stackcmd[index] = letcommand
    LineEdit.edit_clear(s)
    LineEdit.edit_insert(s, letcommand)
end

function show_current_stackpos(s, index, bonus=0)
    # Show stacktrace
    LineEdit.edit_clear(s)
    term = terminal(s)
    print(term, "\r\u1b[K")     # clear the line
    for _ in 1:index+bonus
        print(term, "\r\u1b[K\u1b[A")   # move up while clearing line
    end
    for i = 1:index
        stackitem = stack[i]
        printstyled(term, stackitem[1], '\n'; color=:light_magenta)
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
    # F1
    "^[OP"     => (s, o...) -> showvalue(s),
    # Shift-F1 (deactivate for konsole)
    # F4 (deactivate for konsole)
    "^[OS"    => (s, o...) -> showinputs(s),
)

function customize_keys(repl)
    repl.interface = REPL.setup_interface(repl; extra_repl_keymap = rebuggerkeys)
end


### Utilities

function resizestack(index)
    resize!(stack, index)
    resize!(stackcmd, index)
end

function get_stack_index(callstring)
    index = length(stack)
    hasid = occursin("# stackid $(stackid[])", callstring)
    if hasid
        iend1 = findfirst(isequal('\n'), callstring)
        iend1 = iend1 == nothing ? length(callstring) : iend1
        firstline = callstring[1:iend1]
        mindex = match(r"Main.Rebugger.stack\[(\d+)\]", firstline)
        index = mindex==nothing ? 0 : parse(Int, mindex.captures[1])
    else
        index = 0
    end
    push!(msgs, (index, hasid))
    return index, hasid
end
