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

You can experiment with Rebugger with just

```julia
julia> using Rebugger
```

If you decide you like it (see [Usage](@ref)), you can optionally configure it so that it
is always available (see [Configuration](@ref)).
