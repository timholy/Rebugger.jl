# Limitations

Rebugger is in the early stages of development, and users should currently expect bugs (please do [report](https://github.com/timholy/Rebugger.jl/issues) them).
Neverthess it may be of net benefit for some users.

Here are some known shortcomings:

- Rebugger needs Revise to track packages and source code.
  For scripts use `includet(filename)` to include-and-track.
  (See [Revise's documentation](https://timholy.github.io/Revise.jl/stable/user_reference.html).)
  For stepping into Julia's stdlibs, currently you need a source-build of Julia.
- There are occasional glitches in the display.
  (For brave souls who want to help fix these,
  see [HeaderREPLs.jl](https://github.com/timholy/HeaderREPLs.jl))
- You cannot step into methods defined at the REPL.
- Rebugger runs best in Julia 1.0. While it should run on Julia 0.7,
  a local-scope deprecation can cause some
  problems. If you want 0.7 because of its deprecation warnings and are comfortable
  building Julia, consider building it at commit
  f08f3b668d222042425ce20a894801b385c2b1e2, which removed the local-scope deprecation
  but leaves most of the other deprecation warnings from 0.7 still in place.
- For now you can't step into constructors (it tries to step into `(::Type{T})`)
- If you start `dev`ing a package that you had already loaded, you need to [restart
  your session](https://github.com/timholy/Revise.jl/issues/146)

Another important point (not particularly specific to Rebugger) is that code that
modifies some global state---independent of the input arguments to the method---
can lead to unexpected side effects if you execute it repeatedly.
