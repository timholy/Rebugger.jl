module Rebugger

using UUIDs, InteractiveUtils
using REPL
import REPL.LineEdit, REPL.Terminals
using REPL.LineEdit: buffer, bufend, content, edit_splice!
using REPL.LineEdit: transition, terminal, mode, state

using CodeTracking, Revise, JuliaInterpreter, HeaderREPLs
using Revise: RelocatableExpr, striplines!, printf_maxsize, whichtt, hasfile, unwrap
using JuliaInterpreter: FrameCode, scopeof
using Base.Meta: isexpr
using Core: CodeInfo

# Reexports
export @breakpoint, breakpoint, enable, disable, remove, break_on, break_off

const msgs = []  # for debugging. The REPL-magic can sometimes overprint error messages

include("debug.jl")
include("ui.jl")
include("printing.jl")
include("deepcopy.jl")

# Set up keys that enter rebug mode from the regular Julia REPL
# This should be called from your ~/.julia/config/startup.jl file
function repl_init(repl)
    repl.interface = REPL.setup_interface(repl; extra_repl_keymap = get_rebugger_modeswitch_dict())
end

function rebugrepl_init()
    # Set up the Rebugger REPL mode with all of its key bindings
    repl_inited = isdefined(Base, :active_repl)
    while !isdefined(Base, :active_repl)
        sleep(0.05)
    end
    sleep(0.1) # for extra safety
    # Set up the custom "rebug" REPL
    iprompt, eprompt = rebugrepl_init(Base.active_repl, repl_inited)
    interpret_prompt_ref[] = iprompt
    rebug_prompt_ref[] = eprompt
    return nothing
end

function rebugrepl_init(main_repl, repl_inited)
    irepl = HeaderREPL(main_repl, InterpretHeader())
    interface = REPL.setup_interface(irepl; extra_repl_keymap=Dict[])
    iprompt = interface.modes[end]
    erepl = HeaderREPL(main_repl, RebugHeader())
    interface = REPL.setup_interface(erepl; extra_repl_keymap=[get_rebugger_modeswitch_dict(), rebugger_keys])
    eprompt = interface.modes[end]
    add_keybindings(main_repl; override=repl_inited, keybindings...)
    return iprompt, eprompt
end

function __init__()
    # schedule(Task(rebugrepl_init))
    task = Task() do
        try
            rebugrepl_init()
        catch exception
            @error "Rebugger initialization failed" exception=(exception, catch_backtrace())
        end
    end
    schedule(task)
end

include("precompile.jl")
_precompile_()

end # module
