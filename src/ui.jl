const rebug_prompt_string = "rebug> "
const rebug_prompt_ref = Ref{Union{LineEdit.Prompt,Nothing}}(nothing)   # set by __init__

dummy() = nothing
const dummymethod = first(methods(dummy))
const dummyuuid   = UUID(UInt128(0))

uuidextractor(str) = match(r"getstored\(\"([a-z0-9\-]+)\"\)", str)

mutable struct RebugHeader <: AbstractHeader
    warnmsg::String
    errmsg::String
    uuid::UUID
    current_method::Method
    nlines::Int   # size of the printed header
end
RebugHeader() = RebugHeader("", "", dummyuuid, dummymethod, 0)

function header(s::LineEdit.MIState)
    rebug_prompt = rebug_prompt_ref[]
    rebug_prompt.repl.header
end

# Custom methods
set_method!(header::RebugHeader, method::Method) = header.current_method = method

function set_uuid!(header::RebugHeader, uuid::UUID)
    if haskey(stored, uuid)
        header.uuid = uuid
        header.current_method = stored[uuid].method
    else
        header.uuid = dummyuuid
        header.current_method = dummymethod
    end
    uuid
end

function set_uuid!(header::RebugHeader, str::AbstractString)
    m = uuidextractor(str)
    uuid = if m isa RegexMatch && length(m.captures) == 1
        UUID(m.captures[1])
    else
        dummyuuid
    end
    set_uuid!(header, uuid)
end

struct FakePrompt{Buf<:IO}
    input_buffer::Buf
end
LineEdit.mode(p::FakePrompt) = rebug_prompt_ref[]

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
function stepin(s::LineEdit.MIState)
    # Add the command we're tracing to the history. That way we can go "up the call stack".
    pos = position(s)
    cmd = String(take!(copy(LineEdit.buffer(s))))
    add_history(s, cmd)
    # Analyze the command string and step in
    local uuid, letcmd
    try
        uuid, letcmd = stepin(LineEdit.buffer(s))
    catch err
        repl = rebug_prompt_ref[].repl
        handled = false
        if err isa StashingFailed
            repl.header.warnmsg = "Execution did not reach point"
            handled = true
        elseif err isa Meta.ParseError || err isa StepException
            repl.header.warnmsg = "Expression at point is not a call expression"
            handled = true
        elseif err isa EvalException
            repl.header.errmsg = "$(typeof(err.exception)) exception while evaluating $(err.exprstring)"
            handled = true
        elseif err isa DefMissing
            repl.header.errmsg = "The expression for method $(err.method) was unavailable. Perhaps it was generated by code."
            handled = true
        end
        if handled
            buf = LineEdit.buffer(s)
            LineEdit.edit_clear(buf)
            write(buf, cmd)
            seek(buf, pos)
            return nothing
        end
        rethrow(err)
    end
    set_uuid!(header(s), uuid)
    LineEdit.edit_clear(s)
    LineEdit.edit_insert(s, letcmd)
    return nothing
end

function capture_stacktrace(s)
    if mode(s) isa LineEdit.PrefixHistoryPrompt
        # history search, re-enter with the corresponding mode
        LineEdit.accept_result(s, mode(s))
        return capture_stacktrace(s)
    end
    cmdstring = LineEdit.content(s)
    add_history(s, cmdstring)
    print(REPL.terminal(s), '\n')
    expr = Meta.parse(cmdstring)
    uuids = capture_stacktrace(expr)
    io = IOBuffer()
    buf = FakePrompt(io)
    hp = mode(s).hist
    for uuid in uuids
        println(io, generate_let_command(uuid))
        REPL.add_history(hp, buf)
        take!(io)
    end
    hp.cur_idx = length(hp.history) + 1
    if !isempty(uuids)
        set_uuid!(header(s), uuids[end])
        print(REPL.terminal(s), '\n')
        LineEdit.edit_clear(s)
        LineEdit.enter_prefix_search(s, find_prompt(s, LineEdit.PrefixHistoryPrompt), true)
    end
    return nothing
end

function add_history(s, str::AbstractString)
    io = IOBuffer()
    buf = FakePrompt(io)
    hp = mode(s).hist
    println(io, str)
    REPL.add_history(hp, buf)
end

### REPL mode

function HeaderREPLs.print_header(io::IO, header::RebugHeader)
    if header.nlines == 0
        iocount = IOBuffer()  # for counting lines
        for s in (io, iocount)
            if !isempty(header.warnmsg)
                printstyled(s, header.warnmsg, '\n'; color=Base.warn_color())
            end
            if !isempty(header.errmsg)
                printstyled(s, header.errmsg, '\n'; color=Base.error_color())
            end
            if header.current_method != dummymethod
                printstyled(s, header.current_method, '\n'; color=:light_magenta)
            end
            if header.uuid != dummyuuid
                data = stored[header.uuid]
                ds = displaysize(io)
                printer(args...) = printstyled(args..., '\n'; color=:light_blue)
                for (name, val) in zip(data.varnames, data.varvals)
                    # Make sure each only spans one line
                    try
                        Revise.printf_maxsize(printer, s, "  ", name, " = ", val; maxlines=1, maxchars=ds[2]-1)
                    catch # don't error just because a print method is borked
                        printstyled(s, "  ", name, " errors in its show method"; color=:red)
                    end
                end
            end
        end
        header.nlines = count_display_lines(iocount, displaysize(io))
        header.warnmsg = ""
        header.errmsg = ""
    end
    return nothing
end

function HeaderREPLs.setup_prompt(repl::HeaderREPL{RebugHeader}, hascolor::Bool)
    julia_prompt = find_prompt(repl.interface, "julia")

    prompt = REPL.LineEdit.Prompt(
        rebug_prompt_string;
        prompt_prefix = hascolor ? repl.prompt_color : "",
        prompt_suffix = hascolor ?
            (repl.envcolors ? Base.input_color : repl.input_color) : "",
        complete = julia_prompt.complete,
        on_enter = REPL.return_callback)

    prompt.on_done = HeaderREPLs.respond(repl, julia_prompt) do str
        Base.parse_input_line(str; filename="REBUG")
    end
    # hist will be handled automatically if repl.history_file is true
    # keymap_dict is separate
    return prompt, :rebug
end

function HeaderREPLs.append_keymaps!(keymaps, repl::HeaderREPL{RebugHeader})
    julia_prompt = find_prompt(repl.interface, "julia")
    kms = [
        trigger_search_keymap(repl),
        mode_termination_keymap(repl, julia_prompt),
        trigger_prefix_keymap(repl),
        REPL.LineEdit.history_keymap,
        REPL.LineEdit.default_keymap,
        REPL.LineEdit.escape_defaults,
    ]
    append!(keymaps, kms)
end

# To get it to parse the UUID whenever we move through the history, we have to specialize
# this method
function HeaderREPLs.activate_header(header::RebugHeader, p, s, termbuf, term)
    str = String(take!(copy(LineEdit.buffer(s))))
    set_uuid!(header, str)
end

const keybindings = Dict{Symbol,String}(
    :stacktrace => Sys.iswindows() ? "\x1bs" : "\e[15~",  # Alt-s or F5
    :stepin => Sys.iswindows() ? "\x1be" : "\e\eOM",  # Alt-e or Alt-Shift-Enter
    :deprecated_stepin => "\e[23~",  # F11
)

const modeswitches = Dict{Any,Any}(
    :stacktrace => (s, o...) -> capture_stacktrace(s),
    :stepin => (s, o...) -> (stepin(s); enter_rebug(s)),
    :deprecated_stepin => (s, o...) -> (stepin(s); rebug_prompt_ref[].repl.header.warnmsg="stepin is now Alt-Shift-Enter"; enter_rebug(s)),
)

function get_rebugger_modeswitch_dict()
    rebugger_modeswitch = Dict()
    for (action, keybinding) in keybindings
        rebugger_modeswitch[keybinding] = modeswitches[action]
    end
    rebugger_modeswitch
end

function add_keybindings(; override::Bool=false, kwargs...)
    for (action, keybinding) in kwargs
        if !(action in keys(keybindings))
            error("$action is not a supported action.")
        end
        if !(keybinding isa String)
            error("Expected the value for $action to be a String, got $keybinding instead")
        end
        keybindings[action] = keybinding
        main_repl = Base.active_repl
        history_prompt = find_prompt(main_repl.interface, LineEdit.PrefixHistoryPrompt)
        julia_prompt = find_prompt(main_repl.interface, "julia")
        rebug_prompt = find_prompt(main_repl.interface, "rebug")
        # We need Any here because "cannot convert REPL.LineEdit.PrefixHistoryPrompt to an object of type REPL.LineEdit.Prompt"
        prompts = Any[julia_prompt, rebug_prompt]
        if action == :stacktrace push!(prompts, history_prompt) end
        for prompt in prompts
            LineEdit.add_nested_key!(prompt.keymap_dict, keybinding, modeswitches[action], override=override)
        end
    end
end

# These work only at the `rebug>` prompt
const rebugger_keys = Dict{Any,Any}(
)

## REPL commands TODO?:
## "\em" (meta-m): create REPL line that populates Main with arguments to current method
## "\eS" (meta-S): save version at REPL to file? (a little dangerous, perhaps make it configurable as to whether this is on)
## F1 is "^[OP" (showvalues?), F4 is "^[OS" (showinputs?)


enter_rebug(s) = mode_switch(s, rebug_prompt_ref[])

function mode_switch(s, other_prompt)
    buf = copy(LineEdit.buffer(s))
    LineEdit.edit_clear(s)
    LineEdit.transition(s, other_prompt) do
        LineEdit.state(s, other_prompt).input_buffer = buf
    end
end

# julia_prompt = find_prompt(main_repl.interface, "julia")
# julia_prompt.keymap_dict['|'] = (s, o...) -> enter_count(s)
