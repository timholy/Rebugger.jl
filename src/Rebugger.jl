module Rebugger

using REPL, Random, UUIDs
using REPL.LineEdit, REPL.Terminals
using REPL.LineEdit: MIState, PromptState, InputAreaState
using REPL.LineEdit: buffer, bufend, content, edit_splice!
using REPL.LineEdit: transition, terminal, mode, state
using Revise
using Revise: ExLike, RelocatableExpr, get_signature, funcdef_body, get_def, striplines!
using Revise: printf_maxsize

const rebug_prompt_string = "rebug> "

include("debug.jl")
include("ui.jl")

function __init__()
    atreplinit(Rebugger.repl_init)
    # Create a special terminal for use in rebug mode. The terminal allows for display
    # of a "header" of information separately from the input buffer.
    # This initialization is super-ugly. The issue is that the PromptState is initialized
    # by `run_interface` and we still need to wait for Pkg to define its REPL mode.
    # So if we do our own initialization now, it will just be overwritten later.
    # Strategy: let it do its thing, then we swoop in with the fix once it's done.
    @async begin
        while !isdefined(Base, :active_repl)
            sleep(0.05)
        end
        sleep(0.1) # for extra safety
        repl = Base.active_repl
        # Find the rebug prompt
        local rebug_prompt
        for m in repl.interface.modes
            if isdefined(m, :prompt) && m.prompt == rebug_prompt_string
                rebug_prompt = m
                break
            end
        end
        if !@isdefined(rebug_prompt)
            push!(msgs, "__init__: unable to find the rebug_prompt")
            return nothing
        end

        ps = state(repl.mistate, rebug_prompt)
        push!(msgs, steal_terminal!(ps))
    end
end

end # module
