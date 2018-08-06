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

# function msgs_uuid(str::AbstractString)
#     m = uuidextractor(str)
#     uuid = if m isa RegexMatch && length(m.captures) == 1
#         push!(msgs, m.captures[1])
#     end
#     nothing
# end

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
    uuid, letcmd = stepin(LineEdit.buffer(s))
    set_uuid!(header(s), uuid)
    LineEdit.edit_clear(s)
    LineEdit.edit_insert(s, letcmd)
    return nothing
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
    uuids = capture_stacktrace(expr)
    io = IOBuffer()
    buf = FakePrompt(io)
    hp = mode(s).hist
    for uuid in uuids
        println(io, generate_let_command(uuid))
        REPL.add_history(hp, buf)
        take!(io)
    end
    if !isempty(uuids)
        LineEdit.edit_clear(s)
        LineEdit.edit_insert(s, hp.history[end])
        set_uuid!(header(s), uuids[end])
    end
    return nothing
end

# function showvalue(s)
#     callstring = LineEdit.content(s)
#     index, hasid = get_stack_index(callstring)
#     if hasid
#         p = position(s)
#     end
# end

### REPL mode

function HeaderREPLs.print_header(io::IO, header::RebugHeader)
    nlines = 0
    iocount = IOBuffer()  # for counting lines
    for s in (io, IOContext(iocount, :displaysize => displaysize()))
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
            printer(args...) = printstyled(args..., '\n'; color=:light_blue)
            for (name, val) in zip(data.varnames, data.varvals)
                # Make sure each only spans one line
                Revise.printf_maxsize(printer, s, "  ", name, " = ", val; maxlines=1)
            end
        end
    end
    seek(iocount, 0)
    header.nlines = countlines(iocount)
end

HeaderREPLs.nlines(terminal, header::RebugHeader) = header.nlines

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

## Key bindings

# These work at the `julia>` prompt and the `rebug>` prompt
const rebugger_modeswitch = Dict{Any,Any}(
    # F5
    "\e[15~"   => (s, o...) -> (capture_stacktrace(s); enter_rebug(s)),
    # F11. Note for `konsole` (KDE) users, F11 means "fullscreen". Turn off in Settings->Configure Shortcuts
    "\e[23~"   => (s, o...) -> (stepin(s); enter_rebug(s)),
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


enter_rebug(s) = mode_switch(s, rebug_prompt_ref[])

function mode_switch(s, other_prompt)
    buf = copy(LineEdit.buffer(s))
    LineEdit.edit_clear(s)
    LineEdit.transition(s, other_prompt) do
        LineEdit.state(s, other_prompt).input_buffer = buf
    end
end

# function modify(s, repl, diff)
#     clear_io(state(s), repl)
#     repl.header.n = max(0, repl.header.n + diff)
#     refresh_header(s, repl; clearheader=false)
# end

# @noinline increment(s, repl) = modify(s, repl, +1)
# @noinline decrement(s, repl) = modify(s, repl, -1)

# special_keys = Dict{Any,Any}(
#     '+' => (s, repl, str) -> increment(s, repl),
#     '-' => (s, repl, str) -> decrement(s, repl),
# )


# # Modify repl keymap so '|' enters the count> prompt
# # (Normally you'd use the atreplinit mechanism)
# function enter_count(s)
#     prompt = find_prompt(s, "count")
#     # transition(s, prompt) do
#     #     refresh_header(s, prompt.repl)
#     # end
#     transition(s, prompt)
# end
# julia_prompt = find_prompt(main_repl.interface, "julia")
# julia_prompt.keymap_dict['|'] = (s, o...) -> enter_count(s)
