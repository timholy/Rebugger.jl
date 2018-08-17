# Introduction to Rebugger

Rebugger is an expression-level debugger for Julia.
It has no ability to interact with or manipulate call stacks (see [ASTInterpreter2](https://github.com/Keno/ASTInterpreter2.jl)),
but it can trace execution via the manipulation of Julia expressions.

The name "Rebugger" has 3 meanings:

- it is a REPL-based debugger (more on that below)
- it is the [Revise](https://github.com/timholy/Revise.jl)-based debugger
- it supports repeated-execution debugging

## Installation and configuration

Begin with

```julia
(v1.0) pkg> add Rebugger
```

However, for Rebugger to work you **must** add something similar to the
following lines to your `.julia/config/startup.jl` file:

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
    atreplinit(Rebugger.repl_init)
catch
    @warn "Could not turn on Rebugger key bindings."
end
```

The reason is that Rebugger adds some custom key bindings to the REPL, and **adding new
key bindings works only if it is done before the REPL starts.**

Starting Rebugger from a running Julia session will not do anything useful.

