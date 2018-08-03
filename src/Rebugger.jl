module Rebugger

using REPL, Random, UUIDs
using REPL.LineEdit
using REPL.LineEdit: bufend, content, edit_splice!
using Revise
using Revise: ExLike, RelocatableExpr, get_signature, funcdef_body, get_def, striplines!
using Revise: printf_maxsize

include("debug.jl")
include("ui.jl")

end # module
