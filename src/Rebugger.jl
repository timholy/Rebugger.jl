module Rebugger

using UUIDs
using REPL
import REPL.LineEdit, REPL.Terminals
using REPL.LineEdit: buffer, bufend, content, edit_splice!
using REPL.LineEdit: transition, terminal, mode, state

using Revise
using Revise: ExLike, RelocatableExpr, get_signature, funcdef_body, get_def, striplines!
using Revise: printf_maxsize
using HeaderREPLs

include("debug.jl")
include("ui.jl")

# Set up keys that enter rebug mode from the regular Julia REPL
# This should be called from your ~/.julia/config/startup.jl file
function repl_init(repl)
    repl.interface = REPL.setup_interface(repl; extra_repl_keymap = rebugger_modeswitch)
end

function __init__()
    # Set up the Rebugger REPL mode with all of its key bindings
    @async begin
        while !isdefined(Base, :active_repl)
            sleep(0.05)
        end
        sleep(0.1) # for extra safety
        main_repl = Base.active_repl
        repl = HeaderREPL(main_repl, RebugHeader())
        interface = REPL.setup_interface(repl; extra_repl_keymap=[rebugger_modeswitch, rebugger_keys])
        rebug_prompt_ref[] = interface.modes[end]
    end
end

end # module
