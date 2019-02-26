module Rebugger

using UUIDs
using REPL
import REPL.LineEdit, REPL.Terminals
using REPL.LineEdit: buffer, bufend, content, edit_splice!
using REPL.LineEdit: transition, terminal, mode, state

using CodeTracking, Revise
using Revise: RelocatableExpr, striplines!, printf_maxsize, whichtt, hasfile, unwrap
using HeaderREPLs

const msgs = []  # for debugging. The REPL-magic can sometimes overprint error messages

include("debug.jl")
include("ui.jl")
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
    main_repl = Base.active_repl
    repl = HeaderREPL(main_repl, RebugHeader())
    interface = REPL.setup_interface(repl; extra_repl_keymap=[get_rebugger_modeswitch_dict(), rebugger_keys])
    rebug_prompt_ref[] = interface.modes[end]
    add_keybindings(; override=repl_inited, deprecated_keybindings..., keybindings...)
end


function __init__()
    schedule(Task(rebugrepl_init))
end

include("precompile.jl")
_precompile_()

end # module
