# Usage

Rebugger works from Julia's native REPL prompt. Currently there are two important keybindings:

- Alt-Shift-Enter maps to "step in"
- F5 maps to "capture stacktrace" (for commands that throw an error)

## Stepping in

Select the expression you want to step into by positioning "point" (your cursor)
at the desired location in the command line:

```@raw html
<img src="images/stepin1.png" width="200px"/>
```

Now if you hit Alt-Shift-Enter, you should see something like this:

```@raw html
<img src="images/stepin2.png" width="822px"/>
```

The magenta tells you which method you are stepping into.
The blue shows you the value(s) of any input arguments or type parameters.

Note the user has moved the cursor to another `show` call. Hit Alt-Shift-Enter again.
Now let's illustrate another important display item: if you position your cursor
as shown and hit Alt-Shift-Enter again, you should get the following:

```@raw html
<img src="images/stepin3.png" width="859px"/>
```

Note the yellow/orange line: this is a warning message, and you should pay attention to these.
In this case the call actually enters `show_vector`; if you moved your cursor there,
you could trace execution more completely.

## Capturing stacktraces

Choose a command that throws an error, for example:

```@raw html
<img src="images/capture_stacktrace1.png" width="677px"/>
```

Enter the command again, and this time hit F5:

```@raw html
<img src="images/capture_stacktrace2.png" width="987px"/>
```

Hit enter and you should see the error again, but this time with a much shorter
stacktrace.
That's because you entered at the top of the stacktrace.

You can use your up and down errors to step through the history, which corresponds
to going up and down the stack trace.

Sometimes the portions of the stacktrace you can navigate with the arrows
differs from what you see in the original error:

```@raw html
<img src="images/capture_stacktrace_Pkg.png" width="453px"/>
```

Note that only five methods got captured but the stacktrace is much longer.
Most of these methods, however, start with `#`, an indication that they are
generated methods rather than ones that appear in the source code.
The interactive stacktrace examines only those methods that appear in the source code.

**Note**: `Pkg` is one of Julia's standard libraries, and to step into or trace Julia's stdlibs
you must build Julia from source.
