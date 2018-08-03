const msgs        = []   # for debugging (info sent directly to terminal might be overwritten before it is seen)

"""
    stepin(s)

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

    @eval ModuleOf_fcomplex let (x, y, z, kw1, A, T) = Main.Rebugger.getstored(id)
        <body>
    end

where `Rebugger.getstored` returns has been pre-loaded with the values that would have been
set when you called `fcomplex(x)` in `s` above.
This line can be edited and `eval`ed at the REPL to analyze or improve `fcomplex`,
or can be used for further `stepin` calls.
"""
function stepin(s::MIState)
    letcmd = stepin(buffer(s))
    LineEdit.edit_clear(s)
    # metadata && show_current_stackpos(s, index, -1)
    LineEdit.edit_insert(s, letcmd)
    return nothing

    # @label writeback
    # LineEdit.edit_clear(s)
    # LineEdit.edit_insert(s, callstring)
    # return nothing
end

# function stepup(s)
#     callstring = LineEdit.content(s)
#     index, hasid = get_stack_index(callstring)
#     if hasid && index > 1
#         letcommand = stackcmd[index-1]
#         show_current_stackpos(s, index-1, 1)
#         LineEdit.edit_insert(s, letcommand)
#     end
#     return nothing
# end

# function stepdown!(s)
#     callstring = LineEdit.content(s)
#     index, hasid = get_stack_index(callstring)
#     if hasid && index < length(stack)
#         letcommand = stackcmd[index+1]
#         show_current_stackpos(s, index+1, -1)
#         LineEdit.edit_insert(s, letcommand)
#     end
#     return nothing
# end

function capture_stacktrace(s)
    push!(msgs, "stacktrace")
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


### REPL mode

function mode_switch(s, other_prompt)
    buf = copy(buffer(s))
    transition(s, other_prompt) do
        state(s, other_prompt).input_buffer = buf
    end
end

## Key bindings

# These work at the `julia>` prompt and the `rebug>` prompt
const rebugger_modeswitch = Dict{Any,Any}(
    # F12
    "\e[24~"   => (s, o...) -> toggle_rebug(s),
    # F5
    "\e[15~"   => (s, o...) -> (enter_rebug(s); capture_stacktrace(s)),
    # F11. Note for `konsole` (KDE) users, F11 means "fullscreen". Turn off in Settings->Configure Shortcuts
    "\e[23~"   => (s, o...) -> (enter_rebug(s); stepin(s)),
)

# These work only at the `rebug>` prompt
const rebugger_keys = Dict{Any,Any}(
    # # Shift-F11
    # "\e[23;2~" => (s, o...) -> stepup(s),
    # # Ctrl-F11
    # "\e[23;5~" => (s, o...) -> stepdown(s),
)

## REPL commands TODO?:
## "\em" (meta-m): create REPL line that populates Main with arguments to current method
## "\eS" (meta-S): save version at REPL to file? (a little dangerous, perhaps make it configurable as to whether this is on)
## F1 is "^[OP" (showvalues?), F4 is "^[OS" (showinputs?)

function repl_init(repl)
    repl.interface = REPL.setup_interface(repl; extra_repl_keymap = rebugger_modeswitch)

    # Add a new rebug interface, stealing features from the julia prompt
    local julia_prompt
    for m in repl.interface.modes
        if isdefined(m, :prompt) && m.prompt == "julia> "
            julia_prompt = m
            break
        end
    end
    if !@isdefined(julia_prompt)
        @warn "unable to find the julia_prompt, rebugger prompt not defined"
        return repl.interface
    end

    hp = julia_prompt.hist

    rebug_prompt = Prompt("rebug> ";
                          prompt_prefix = julia_prompt.prompt_prefix,
                          prompt_suffix = julia_prompt.prompt_suffix,
                          repl = repl,
                          complete = julia_prompt.complete,
                          hist = hp,
                          on_enter = julia_prompt.on_enter,
                          sticky = true)
    rebug_prompt.on_done = REPL.respond(x->Base.parse_input_line(x,filename=REPL.repl_filename(repl,rebug_prompt.hist)), repl, rebug_prompt)

    search_prompt, skeymap = LineEdit.setup_search_keymap(hp)
    prefix_prompt, prefix_keymap = LineEdit.setup_prefix_keymap(hp, rebug_prompt)

    rebug_prompt.keymap_dict = LineEdit.keymap(Dict{Any,Any}[
        REPL.mode_keymap(julia_prompt),  # back to `julia>` if hit ^C or backspace at beginning of line
        rebugger_modeswitch,
        rebugger_keys,
        skeymap,
        prefix_keymap,
        LineEdit.default_keymap,         # typical "emacs-mode" movement and editing key bindings
        LineEdit.escape_defaults])       # arrow keys etc

    # Ensure history entries are attributed to rebug mode
    hp.mode_mapping[:rebug] = rebug_prompt

    # Defined internally because we need access to both julia_prompt and rebug_prompt,
    # but this function must be available globally.
    @eval function toggle_rebug(s)
        push!(msgs, stacktrace(backtrace()))
        other_prompt = if mode(s) == $julia_prompt
            $rebug_prompt
        elseif mode(s) == $rebug_prompt
            $julia_prompt
        else
            return
        end
        mode_switch(s, other_prompt)
    end
    @eval enter_rebug(s) = mode_switch(s, $rebug_prompt)

    push!(repl.interface.modes, rebug_prompt)
end
