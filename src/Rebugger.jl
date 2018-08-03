module Rebugger

using REPL, Random, UUIDs
using REPL.LineEdit, REPL.Terminals
using REPL.LineEdit: MIState, PromptState, InputAreaState
using REPL.LineEdit: buffer, bufend, content, edit_splice!
using REPL.LineEdit: transition, terminal, mode, state
using Revise
using Revise: ExLike, RelocatableExpr, get_signature, funcdef_body, get_def, striplines!
using Revise: printf_maxsize

include("debug.jl")
include("ui.jl")

end # module
