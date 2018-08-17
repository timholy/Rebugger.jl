# How Rebugger works

Rebugger traces execution through use of expression-rewriting and Julia's ordinary
`try/catch` control-flow.
It maintains internal storage that allows other methods to "deposit" their arguments
(a *store*) or temporarily *stash* the function and arguments of a call.

## Implementation of "step in"

Rebugger makes use of the buffer containing user input: not just its contents, but also
the position of "point" (the seek position) to indicate the specific call expression
targeted for stepping in.

For example, if a buffer has contents

```julia
    # <some code>
    if x > 0.5
        ^fcomplex(x, 2; kw1=1.1)
        # <more code>
```

where in the above `^` indicates "point," Rebugger uses a multi-stage process
to enter `fcomplex` with appropriate arguments:

- First, it carries out *caller capture* to determine which function is being called
  at point, and with which arguments. The main goal here is to be able to then use
  `which` to determine the specific method.
- Once armed with the specific method, it then carries out *callee capture* to
  obtain all the inputs to the method. For simple methods this may be redundant
  with *caller capture*, but *callee capture* can also obtain the values of
  default arguments, keyword arguments, and type parameters.
- Finally, Rebugger rewrites the REPL command-line buffer with a suitably-modified
  version of the body of the appropriate method, so that the user can inspect and
  manipulate it.

### Caller capture

The original expression above is rewritten as

```julia
    # <some code>
    if x > 0.5
        Main.Rebugger.stashed[] = (fcomplex, (x, 2), (kw1=1.1,))
        throw(Rebugger.StopException())
        # <more code>
```

Note that the full context of the original expression is preserved, thereby ensuring
that we do not have to be concerned about not having the appropriate local scope for
the arguments to the call of `fcomplex`.
However, rather than actually calling `fcomplex`, this expression "stashes" the
arguments and function in a temporary store internal to Rebugger.
It then throws an exception type specifically crafted to signal that the expression
executed and exited as expected.

This expression is then evaluated inside a block

```julia
    try
        Core.eval(Main, caller_capture_expression)
        throw(StashingFailed())
    catch err
        err isa StashingFailed && rethrow(err)
        if !(err isa StopException)
            throw(EvalException(content(buffer), err))
        end
    end
```

Note that this looks for the `StopException`; this is considered the normal execution
path.
If the `StopException` is never hit, it means evaluation never reached the expression
marked by "point" and thus leads to a `StashingFailed` exception.
Any other error results in an `EvalException`, usually triggered by other errors
in the block of code.

Assuming the `StopException` is hit, we then proceed to callee capture.

### Callee capture

Rebugger removes the function and arguments from `Rebugger.stashed[]` and then uses
`which` to determine the specific method called.
It then asks [Revise](https://timholy.github.io/Revise.jl/stable/) for the expression
that defines the method.
It then analyzes the signature to determine the full complement of inputs and creates
a new method that stores them. For example, if the applicable method of `fcomplex` is
given by

```julia
    function fcomplex(x::A, y=1, z=""; kw1=3.2) where A<:AbstractArray{T} where T
        # <body>
    end
```

then Rebugger generates a new method

```julia
    function hidden_fcomplex(x::A, y=1, z=""; kw1=3.2) where A<:AbstractArray{T} where T
        Main.Rebugger.stored[uuid] = Main.Rebugger.Stored(fcomplex, (:x, :y, :z, :kw1, :A, :T), deepcopy((x, y, z, kw1, A, T)))
        throw(StopException())
    end
```

This method is then called from inside another `try/catch` block that again checks for a `StopException`.
This results in the complete set of inputs being *stored*, a more "permanent" form
of preservation than *stashing*, which only lasts for the gap between caller and callee capture.
If one has the appropriate `uuid`, one can then extract these values at will from storage
using [`Rebugger.getstored`](@ref).

### Generating the new buffer contents (the `let` expression)

Once callee capture is complete, the user can re-execute any components of the called method
as desired. To make this easier, Rebugger replaces the contents of the buffer with a line that
looks like this:

```julia
@eval <ModuleOf_fcomplex> let (x, y, z, kw1, A, T) = Main.Rebugger.getstored("0123abc...")
    # <body>
end
```

The `@eval` makes sure that the block will be executed within the module in which
`fcomplex` is defined; as a consequence it will have access to all the unexported methods,
etc., that `fcomplex` itself has.
The `let` block ensures that these variables do not conflict with other objects that
may be defined in `ModuleOf_fcomplex`.
The values are unloaded from the store (making copies, in case `fcomplex` modifies its
inputs) and then execution proceeds into `body`.

The user can then edit the buffer at will.

## Implementation of "catch stacktrace"

In contrast with "step in," when catching a stacktrace Rebugger does not know the specific
methods that will be used in advance of making the call.
Consequently, Rebugger has to execute the call twice:

- the first call is used to obtain a stacktrace
- The trace is analyzed to obtain the specific methods, which are then replaced with versions
  that place inputs in storage; see [Callee capture](@ref), with the differences
  + the original method is (temporarily) overwritten by one that executes the store
  + this "storing" method also includes the full method body
  These two changes ensure that the "call chain" is not broken.
- a second call (recreating the same error, for functions that have deterministic execution)
  is then made to store all the arguments at each captured stage of the stacktrace.
- finally, the original methods are restored.
