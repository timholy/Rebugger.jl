# Configuration

If you decide you like Rebugger, you can add lines such as the following to your
`~/.julia/config/startup.jl` file:

```julia
try
    @eval using Revise
    # Turn on Revise's file-watching behavior
    Revise.async_steal_repl_backend()
catch
    @warn "Could not load Revise."
end

try
    @eval using Rebugger
    # Activate Rebugger's key bindings
    atreplinit(Rebugger.repl_init)
catch
    @warn "Could not turn on Rebugger key bindings."
end
```
