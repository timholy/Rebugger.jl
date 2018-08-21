# Configuration

## Run on REPL startup

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

## Customize keybindings

It's possible that Rebugger's default keybindings don't work for you.
This can be for various reasons. Some window managers override the Rebugger's
keybindings with their own. Some terminals map the keybindings used by Rebugger
to different escape sequences than those hardcoded in Rebugger. You can work
around these issues by adding your own keybindings.

To add your own keybindings, use `Rebugger.add_keybindings(action=keybinding, ...)`.
This can be done during a running Rebugger session. Here is an example that
maps the "step in" action to the key "F6" and "capture stacktrace" to "F7"

```julia
julia> Rebugger.add_keybindings(stepin="\e[17~", stacktrace="\e[18~")
```

To make your keybindings permanent, change the "Rebugger" section of your `startup.jl` file
to something like:
```julia
try
    @eval using Rebugger
    # Activate Rebugger's key bindings
    Rebugger.keybindings[:stepin] = "\e[17~"      # Add the keybinding F6 to step into a function.
    Rebugger.keybindings[:stacktrace] = "\e[18~"  # Add the keybinding F7 to capture a stacktrace.
    atreplinit(Rebugger.repl_init)
catch
    @warn "Could not load Rebugger."
end
```

But how to find out the cryptic string that corresponds to the keybinding you
want? Use Julia's `read()` function:

```julia
julia> str = read(stdin, String)
^[[17~"\e[17~"  # Press F6, followed by Ctrl+D, Ctrl+D

julia> str
"\e[17~"
```

After calling `read()`, press the keybinding that you want. Then, press `Ctrl+D`
twice to terminate the input. The value of `str` is the cryptic string you are
looking for.
