using Rebugger, Test

@info "These tests manipulate the console. Wait until you see \"Done\""
include("edit.jl")
include("interpret.jl")
if Sys.isunix() && VERSION >= v"1.1.0"
    include("interpret_ui.jl")
else
    @warn "Skipping UI tests"
end
println("Done")
