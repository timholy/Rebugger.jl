const msgs        = []   # for debugging (info sent directly to terminal might be overwritten before it is seen)

dummy() = nothing
const dummymethod = first(methods(dummy))

uuidextractor(str) = match(r"getstored\(\"([a-z0-9\-]+)\"\)", str)

mutable struct RebugTerminal <: Terminals.UnixTerminal
    # Fields from TTYTerminal
    term_type::String
    in_stream::IO
    out_stream::IO
    err_stream::IO
    # Size of the printed header. The header is what motivates a new terminal type,
    # specifically because LineEdit.clear_input_area only takes a terminal and an ias.
    # The ias (stored in PromptState) is used to understand the extent of the
    # user input buffer, and thus can't include any lines not related to user input.
    # Consequently we have to be able to correct it to include the header.
    nlines::Int
    # Additional fields
    warnmsg::String
    errmsg::String
    current_method::Method
end
RebugTerminal(term::Terminals.TTYTerminal) =
    RebugTerminal(term.term_type, term.in_stream, term.out_stream, term.err_stream,
                  0, "", "", dummymethod)

tty(term::RebugTerminal) =
    Terminals.TTYTerminal(term.term_type, term.in_stream, term.out_stream, term.err_stream)

function steal_terminal!(state::PromptState)
    term = terminal(state)
    term isa RebugTerminal && return term
    state.terminal = RebugTerminal(term)
end

# Forward some terminal operations to the tty
Terminals.raw!(t::RebugTerminal, raw::Bool) = Terminals.raw!(tty(t), raw)
Terminals.hascolor(t::RebugTerminal) = Terminals.hascolor(tty(t))
Base.in(key_value::Pair, t::RebugTerminal) = in(key_value, pipe_writer(tty(t)))
Base.haskey(t::RebugTerminal, key) = haskey(pipe_writer(tty(t)), key)
Base.getindex(t::RebugTerminal, key) = getindex(pipe_writer(tty(t)), key)
Base.get(t::RebugTerminal, key, default) = get(pipe_writer(tty(t)), key, default)
Base.peek(t::RebugTerminal) = Base.peek(t.in_stream)

# Display of Rebug info
function clear_lines(terminal::Terminals.UnixTerminal, n)
    for i = 1:n
        Terminals.clear_line(terminal)
        Terminals.cmove_up(terminal)
    end
end

function LineEdit._clear_input_area(t::RebugTerminal, state::InputAreaState)
    ty = tty(t)
    LineEdit._clear_input_area(ty, state)
    clear_lines(ty, t.nlines)
end

function LineEdit.refresh_multi_line(termbuf::TerminalBuffer, terminal::RebugTerminal, buf::IOBuffer, state::InputAreaState, prompt = "";
                                     indent = 0, region_active = false)
    LineEdit._clear_input_area(terminal, state)
    printstyled(terminal.current_method, '\n'; color=:light_magenta)
    terminal.nlines = 1
    LineEdit.refresh_multi_line(termbuf, tty(terminal), buf, InputAreaState(0, 0), prompt; indent=indent, region_active=region_active)
end

# Custom methods
set_method!(term::RebugTerminal, method::Method) = term.current_method = method

function set_method!(term::RebugTerminal, uuid::UUID)
    term.current_method = if haskey(stored, uuid)
        stored[uuid].method
    else
        dummymethod
    end
end

function set_method!(term::RebugTerminal, str::AbstractString)
    m = uuidextractor(str)
    if m isa RegexMatch && length(m.captures) == 1
        return set_method!(term, UUID(m.captures[1]))
    end
    term.current_method = dummymethod
end

function set_method!(s::MIState, method::Method)
    set_method!(terminal(state(s)), method)
end

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
    method, letcmd = stepin(buffer(s))
    set_method!(s, method)
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
    # Because the rebug prompt might have a different number of lines than the julia prompt,
    # we have to clear before we hand things over
    oldstate, newstate = state(s), state(s, other_prompt)
    term = terminal(oldstate)
    if term isa RebugTerminal
        LineEdit._clear_input_area(term, oldstate.ias)
        oldstate.ias = InputAreaState(0,0)
        term.nlines = 0
    else
        LineEdit._clear_input_area(term, oldstate.ias)
        oldstate.ias = InputAreaState(0,0)
    end
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


    # back to `julia>` if hit ^C or backspace at beginning of line
    # This is like REPL.mode_keymap except for the calling of `mode_switch`
    breakout_keymap = Dict{Any,Any}(
        '\b' => function (s,o...)
            if isempty(s) || position(LineEdit.buffer(s)) == 0
                mode_switch(s, julia_prompt)
            else
                LineEdit.edit_backspace(s)
            end
        end,
        "^C" => function (s,o...)
            LineEdit.move_input_end(s)
            LineEdit.refresh_line(s)
            print(terminal(s), "^C\n\n")
            transition(s, julia_prompt)
            transition(s, :reset)
            LineEdit.refresh_line(s)
        end)

    search_prompt, skeymap = LineEdit.setup_search_keymap(hp)
    prefix_prompt, prefix_keymap = LineEdit.setup_prefix_keymap(hp, rebug_prompt)

    rebug_prompt.keymap_dict = LineEdit.keymap(Dict{Any,Any}[
        breakout_keymap,
        rebugger_modeswitch,
        rebugger_keys,
        skeymap,
        prefix_keymap,
        LineEdit.default_keymap,         # typical "emacs-mode" movement and editing key bindings
        LineEdit.escape_defaults])       # arrow keys etc

    # Ensure history entries are attributed to rebug mode
    hp.mode_mapping[:rebug] = rebug_prompt

    # # Create a special terminal for use in rebug mode
    @async begin
        while !isdefined(Base, :active_repl)
            sleep(0.05)
        end
        steal_terminal!(state(repl.mistate, rebug_prompt))
    end

    # Defined internally because we need access to both julia_prompt and rebug_prompt,
    # but this function must be available globally.
    @eval function toggle_rebug(s)
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
