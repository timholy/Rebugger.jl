using Rebugger, Test

include("edit.jl")
include("interpret.jl")
if Sys.isunix() && VERSION >= v"1.1.0"
    include("interpret_ui.jl")
else
    @warn "Skipping UI tests"
end
println("done")  # there is so much terminal manipulation, best to let the user know
