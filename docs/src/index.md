# Introduction to Rebugger

Rebugger is an expression-level debugger for Julia.
It has no ability to interact with or manipulate call stacks (see [Gallium](https://github.com/Keno/Gallium.jl)),
but it can trace execution via the manipulation of Julia expressions.

The name "Rebugger" has 3 meanings:

- it is a [REPL](https://docs.julialang.org/en/latest/stdlib/REPL/)-based debugger (more on that below)
- it is the [Revise](https://github.com/timholy/Revise.jl)-based debugger
- it supports repeated-execution "surface" debugging

Rebugger is an unusual debugger with a novel work-flow paradigm.
With most debuggers, you enter some special mode that lets the user "dive into the code,"
but what you are allowed to do while in this special mode may be limited.
In contrast, Rebugger brings the code along with its input arguments to the user,
presenting them both for inspection, analysis, and editing in the (mostly) normal Julia
interactive command line.
As a consequence, you can:

- test different modifications to the code or arguments without being forced to exit debug mode
  and save your file
- run the same chosen block of code repeatedly (perhaps with different modifications each time)
  without having to repeat any of the "setup" work that might have been necessary to get to some
  deeply nested method in the original call stack.
  In other words, Rebugger brings "internal" methods to the surface.
- run any desired command that helps you understand the nature of a bug.
  For example, if you've already loaded `MyFavoritePlottingPackage` in your session,
  then when debugging you can (transiently) add `Main.MyFavoritePlottingPackage.plot(x, y)`
  as a line of the method-body you are currently analyzing, and you should see a
  plot of the requested variables.

Rebugger exploits the Julia REPL's history capabilities to simulate the
stacktrace-navigation features of graphical debuggers.
Thus Rebugger offers a command-line experience that is more closely aligned with
graphical debuggers than the traditional `s`, `n`, `up`, `c` commands of a console debugger.

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

The default meta key on Ubuntu is left Alt, which is equivalent to Esc Alt on the default
Gnome terminal emulator.
However, even with this tip you may encounter problems because Rebugger's default key bindings
may be assigned to activate menu options within the terminal window, and
[this appears not to be configurable]( https://bugs.launchpad.net/ubuntu/+source/nautilus/+bug/1113420).
As a consequence Ubuntu users will very likely need to [Customize keybindings](@ref).
