# Limitations

Rebugger is in the early stages of development, and users should currently expect bugs (please do [report](https://github.com/timholy/Rebugger.jl/issues) them).
Nevertheless it may be of net benefit for some users.

Here are some known shortcomings:

- Rebugger only has access to code tracked by Revise.
  To ensure that scripts are tracked, use `includet(filename)` to include-and-track.
  (See [Revise's documentation](https://timholy.github.io/Revise.jl/stable/user_reference.html).)
  For stepping into Julia's stdlibs, currently you need a source-build of Julia.
- You cannot step into methods defined at the REPL.
- For now you can't step into constructors (it tries to step into `(::Type{T})`)
- There are occasional glitches in the display.
  (For brave souls who want to help fix these,
  see [HeaderREPLs.jl](https://github.com/timholy/HeaderREPLs.jl))
- Rebugger runs best in Julia 1.0. While it should run on Julia 0.7,
  a local-scope deprecation can cause some
  problems. If you want 0.7 because of its deprecation warnings and are comfortable
  building Julia, consider building it at commit
  f08f3b668d222042425ce20a894801b385c2b1e2, which removed the local-scope deprecation
  but leaves most of the other deprecation warnings from 0.7 still in place.
- If you start `dev`ing a package that you had already loaded, you need to [restart
  your session](https://github.com/timholy/Revise.jl/issues/146)

Another important point (not particularly specific to Rebugger) is that
repeatedly executing code that modifies some global state
can lead to unexpected side effects.
Rebugger works best on methods whose behavior is determined solely by their input
arguments.

## Note for Ubuntu users

The default meta key on Ubuntu is left Alt, which is equivalent to Esc Alt on the default Gnome terminal emulator. 

### Ubuntu 16.04

Rebugger may not work with the default keyboard shortucts on Ubuntu 16.04. The root of the issue is not solved yet. As a walkaround please re-map the meta keys to function keys, e.g. adding to `startup.jl`

```
    Rebugger.keybindings[:stepin] = "\e[17~"      # Add the keybinding F6 to step into a function.
    Rebugger.keybindings[:stacktrace] = "\e[18~"  # Add the keybinding F7 to capture a stacktrace.
``` 
as stated in the [Customize keybindings](@ref) section to map step-in to F6 and stacktrace to F7.


