# Introduction to Rebugger

Rebugger is an expression-level debugger for Julia.
It has two modes of action:

- an "interpret" mode that lets you step through code, set
  breakpoints, and other manipulations common to "typical" debuggers;
- an "edit" mode that presents method bodies as objects for manipulation,
  allowing you to interactively play with the code at different stages
  of execution.


The name "Rebugger" has 3 meanings:

- it is a [REPL](https://docs.julialang.org/en/latest/stdlib/REPL/)-based debugger (more on that below)
- it is the [Revise](https://github.com/timholy/Revise.jl)-based debugger
- it supports repeated-execution debugging

## Installation

Begin with

```julia
(v1.0) pkg> add Rebugger
```

You can experiment with Rebugger with just

```julia
julia> using Rebugger
```

If you eventually decide you like Rebugger, you can optionally configure it so that it
is always available (see [Configuration](@ref)).

## Keyboard shortcuts

Most of Rebugger's functionality gets triggered by special keyboard shortcuts added to Julia's REPL.
Unfortunately, different operating systems and desktop environments vary considerably in
their key bindings, and it is possible that the default choices in Rebugger are
already assigned other meanings on your platform.
There does not appear to be any one set of choices that works on all platforms.

The best strategy is to try the demos in [Usage](@ref); if the default shortcuts
are already taken on your platform, then you can easily configure Rebugger
to use different bindings (see [Configuration](@ref)).

Some platforms are known to require or benefit from special attention:

#### macOS

If you're on macOS, you may want to enable
"[Use `option` as the Meta key](https://github.com/timholy/Rebugger.jl/issues/28#issuecomment-414852133)"
in your Terminal settings to avoid the need to press Esc before each Rebugger command.

#### Ubuntu

The default meta key on some Ubuntu versions is left Alt, which is equivalent to Esc Alt on the default
Gnome terminal emulator.
However, even with this tip you may encounter problems because Rebugger's default key bindings
may be assigned to activate menu options within the terminal window, and
[this appears not to be configurable]( https://bugs.launchpad.net/ubuntu/+source/nautilus/+bug/1113420).
Affected users may wish to [Customize keybindings](@ref).
