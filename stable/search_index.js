var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#Introduction-to-Rebugger-1",
    "page": "Home",
    "title": "Introduction to Rebugger",
    "category": "section",
    "text": "Rebugger is an expression-level debugger for Julia. It has no ability to interact with or manipulate call stacks (see ASTInterpreter2), but it can trace execution via the manipulation of Julia expressions.The name \"Rebugger\" has 3 meanings:it is a REPL-based debugger (more on that below)\nit is the Revise-based debugger\nit supports repeated-execution debugging"
},

{
    "location": "index.html#Installation-and-configuration-1",
    "page": "Home",
    "title": "Installation and configuration",
    "category": "section",
    "text": "Begin with(v1.0) pkg> add RebuggerHowever, for Rebugger to work you must add something similar to the following lines to your .julia/config/startup.jl file:try\n    @eval using Revise\n    # Turn on Revise\'s file-watching behavior\n    Revise.async_steal_repl_backend()\ncatch\n    @warn \"Could not load Revise.\"\nend\n\ntry\n    @eval using Rebugger\n    atreplinit(Rebugger.repl_init)\ncatch\n    @warn \"Could not turn on Rebugger key bindings.\"\nendThe reason is that Rebugger adds some custom key bindings to the REPL, and adding new key bindings works only if it is done before the REPL starts.Starting Rebugger from a running Julia session will not do anything useful."
},

{
    "location": "usage.html#",
    "page": "Usage",
    "title": "Usage",
    "category": "page",
    "text": ""
},

{
    "location": "usage.html#Usage-1",
    "page": "Usage",
    "title": "Usage",
    "category": "section",
    "text": "Rebugger works from Julia\'s native REPL prompt. Currently there are two important keybindings:Alt-Shift-Enter maps to \"step in\"\nF5 maps to \"capture stacktrace\" (for commands that throw an error)"
},

{
    "location": "usage.html#Stepping-in-1",
    "page": "Usage",
    "title": "Stepping in",
    "category": "section",
    "text": "Select the expression you want to step into by positioning \"point\" (your cursor) at the desired location in the command line:<img src=\"images/stepin1.png\" width=\"200px\"/>Now if you hit Alt-Shift-Enter, you should see something like this:<img src=\"images/stepin2.png\" width=\"822px\"/>The magenta tells you which method you are stepping into. The blue shows you the value(s) of any input arguments or type parameters.Note the user has moved the cursor to another show call. Hit Alt-Shift-Enter again. Now let\'s illustrate another important display item: if you position your cursor as shown and hit Alt-Shift-Enter again, you should get the following:<img src=\"images/stepin3.png\" width=\"859px\"/>Note the yellow/orange line: this is a warning message, and you should pay attention to these. In this case the call actually enters show_vector; if you moved your cursor there, you could trace execution more completely."
},

{
    "location": "usage.html#Capturing-stacktraces-1",
    "page": "Usage",
    "title": "Capturing stacktraces",
    "category": "section",
    "text": "Choose a command that throws an error, for example:<img src=\"images/capture_stacktrace1.png\" width=\"677px\"/>Enter the command again, and this time hit F5:<img src=\"images/capture_stacktrace2.png\" width=\"987px\"/>Hit enter and you should see the error again, but this time with a much shorter stacktrace. That\'s because you entered at the top of the stacktrace.You can use your up and down errors to step through the history, which corresponds to going up and down the stack trace.Sometimes the portions of the stacktrace you can navigate with the arrows differs from what you see in the original error:<img src=\"images/capture_stacktrace_Pkg.png\" width=\"453px\"/>Note that only five methods got captured but the stacktrace is much longer. Most of these methods, however, start with #, an indication that they are generated methods rather than ones that appear in the source code. The interactive stacktrace examines only those methods that appear in the source code.Note: Pkg is one of Julia\'s standard libraries, and to step into or trace Julia\'s stdlibs you must build Julia from source."
},

{
    "location": "limitations.html#",
    "page": "Limitations",
    "title": "Limitations",
    "category": "page",
    "text": ""
},

{
    "location": "limitations.html#Limitations-1",
    "page": "Limitations",
    "title": "Limitations",
    "category": "section",
    "text": "Rebugger is in the very early stages of development, and users should currently expect bugs (please do report them). Neverthess it may be of net benefit for some users.Here are some known shortcomings:F5 sometimes doesn\'t work when your cursor is at the end of the line. Move your cursor anywhere else in that line and try again.\nRebugger needs Revise to track the package. For scripts use includet(filename) to include-and-track. For stepping into Julia\'s stdlibs, currently you need a source-build of Julia.\nThere are known glitches in the display. When capturing stack traces, hit enter on the first one to rethrow the error before trying the up and down arrows to navigate the history–-that seems to reduce the glitching. (For brave souls who want to help fix these, see HeaderREPLs.jl)\nYou cannot step into methods defined at the REPL.\nRebugger runs best in Julia 1.0. While it should run on Julia 0.7, a local-scope deprecation can cause some problems. If you want 0.7 because of its deprecation warnings and are comfortable building Julia, consider building it at commit f08f3b668d222042425ce20a894801b385c2b1e2, which removed the local-scope deprecation but leaves most of the other deprecation warnings from 0.7 still in place.\nFor now you can\'t step into constructors (it tries to step into (::Type{T}))\nIf you start deving a package that you had already loaded, you need to restart your session (https://github.com/timholy/Revise.jl/issues/146)Another important point (not particularly specific to Rebugger) is that code that modifies some global state–-independent of the input arguments to the method–- can lead to unexpected side effects if you execute it repeatedly."
},

{
    "location": "internals.html#",
    "page": "How Rebugger works",
    "title": "How Rebugger works",
    "category": "page",
    "text": ""
},

{
    "location": "internals.html#How-Rebugger-works-1",
    "page": "How Rebugger works",
    "title": "How Rebugger works",
    "category": "section",
    "text": "Rebugger traces execution through use of expression-rewriting and Julia\'s ordinary try/catch control-flow. It maintains internal storage that allows other methods to \"deposit\" their arguments (a store) or temporarily stash the function and arguments of a call."
},

{
    "location": "internals.html#Implementation-of-\"step-in\"-1",
    "page": "How Rebugger works",
    "title": "Implementation of \"step in\"",
    "category": "section",
    "text": "Rebugger makes use of the buffer containing user input: not just its contents, but also the position of \"point\" (the seek position) to indicate the specific call expression targeted for stepping in.For example, if a buffer has contents    # <some code>\n    if x > 0.5\n        ^fcomplex(x, 2; kw1=1.1)\n        # <more code>where in the above ^ indicates \"point,\" Rebugger uses a multi-stage process to enter fcomplex with appropriate arguments:First, it carries out caller capture to determine which function is being called at point, and with which arguments. The main goal here is to be able to then use which to determine the specific method.\nOnce armed with the specific method, it then carries out callee capture to obtain all the inputs to the method. For simple methods this may be redundant with caller capture, but callee capture can also obtain the values of default arguments, keyword arguments, and type parameters.\nFinally, Rebugger rewrites the buffer with the body of the appropriate method, so that the user can inspect and manipulate it."
},

{
    "location": "internals.html#Caller-capture-1",
    "page": "How Rebugger works",
    "title": "Caller capture",
    "category": "section",
    "text": "The original expression above is rewritten as    # <some code>\n    if x > 0.5\n        Main.Rebugger.stashed[] = (fcomplex, (x, 2), (kw1=1.1,))\n        throw(Rebugger.StopException())\n        # <more code>Note that the full context of the original expression is preserved, thereby ensuring that we do not have to be concerned about not having the appropriate local scope for the arguments to the call of fcomplex. However, rather than actually calling fcomplex, this expression \"stashes\" the arguments and function in a temporary store internal to Rebugger. It then throws an exception type specifically crafted to signal that the expression executed and exited as expected.This expression is then evaluated inside a block    try\n        Core.eval(Main, caller_capture_expression)\n        throw(StashingFailed())\n    catch err\n        err isa StashingFailed && rethrow(err)\n        if !(err isa StopException)\n            throw(EvalException(content(buffer), err))\n        end\n    endNote that this looks for the StopException; this is considered the normal execution path. If the StopException is never hit, it means evaluation never reached the expression marked by \"point\" and thus leads to a StashingFailed exception. Any other error results in an EvalException, usually triggered by other errors in the block of code.Assuming the StopException is hit, we then proceed to callee capture."
},

{
    "location": "internals.html#Callee-capture-1",
    "page": "How Rebugger works",
    "title": "Callee capture",
    "category": "section",
    "text": "Rebugger removes the function and arguments from Rebugger.stashed[] and then uses which to determine the specific method called. It then asks Revise for the expression that defines the method. It then analyzes the signature to determine the full complement of inputs and creates a new method that stores them. For example, if the applicable method of fcomplex is given by    function fcomplex(x::A, y=1, z=\"\"; kw1=3.2) where A<:AbstractArray{T} where T\n        # <body>\n    endthen Rebugger generates a new method    function hidden_fcomplex(x::A, y=1, z=\"\"; kw1=3.2) where A<:AbstractArray{T} where T\n        Main.Rebugger.stored[uuid] = Main.Rebugger.Stored(fcomplex, (:x, :y, :z, :kw1, :A, :T), deepcopy((x, y, z, kw1, A, T)))\n        throw(StopException())\n    endThis method is then called from inside another try/catch block that again checks for a StopException. This results in the complete set of inputs being stored, a more \"permanent\" form of preservation than stashing, which only lasts for the gap between caller and callee capture. If one has the appropriate uuid, one can then extract these values at will from storage using Rebugger.getstored."
},

{
    "location": "internals.html#Generating-the-new-buffer-contents-(the-let-expression)-1",
    "page": "How Rebugger works",
    "title": "Generating the new buffer contents (the let expression)",
    "category": "section",
    "text": "Once callee capture is complete, the user can re-execute any components of the called method as desired. To make this easier, Rebugger replaces the contents of the buffer with a line that looks like this:@eval <ModuleOf_fcomplex> let (x, y, z, kw1, A, T) = Main.Rebugger.getstored(\"0123abc...\")\n    # <body>\nendThe @eval makes sure that the block will be executed within the module in which fcomplex is defined; as a consequence it will have access to all the unexported methods, etc., that fcomplex itself has. The let block ensures that these variables do not conflict with other objects that may be defined in ModuleOf_fcomplex. The values are unloaded from the store (making copies, in case fcomplex modifies its inputs) and then execution proceeds into body. If the user edits the buffer, the body can be modified or replaced with custom logic."
},

{
    "location": "internals.html#Implementation-of-\"catch-stacktrace\"-1",
    "page": "How Rebugger works",
    "title": "Implementation of \"catch stacktrace\"",
    "category": "section",
    "text": "In contrast with \"step in,\" when catching a stacktrace Rebugger does not know in advance of making the call the specific methods that will be used. Consequently, Rebugger has to execute the call twice:the first call is used to obtain a stacktrace\nThe trace is analyzed to obtain the specific methods, which are then replaced with versions that place inputs in storage (see Callee capture, with the difference that after storage the full method body is then executed).\na second call (hopefully recreating the same error) is then made to store all the arguments at each captured stage of the stacktrace.\nfinally, the original methods are restored."
},

{
    "location": "reference.html#",
    "page": "Developer reference",
    "title": "Developer reference",
    "category": "page",
    "text": ""
},

{
    "location": "reference.html#Developer-reference-1",
    "page": "Developer reference",
    "title": "Developer reference",
    "category": "section",
    "text": ""
},

{
    "location": "reference.html#Rebugger.stepin",
    "page": "Developer reference",
    "title": "Rebugger.stepin",
    "category": "function",
    "text": "stepin(s)\n\nGiven a buffer s representing a string and \"point\" (the seek position) set at a call expression, replace the contents of the buffer with a let expression that wraps the body of the callee.\n\nFor example, if s has contents\n\n<some code>\nif x > 0.5\n    ^fcomplex(x)\n    <more code>\n\nwhere in the above ^ indicates position(s) (\"point\"), and if the definition of fcomplex is\n\nfunction fcomplex(x::A, y=1, z=\"\"; kw1=3.2) where A<:AbstractArray{T} where T\n    <body>\nend\n\nrewrite s so that its contents are\n\n@eval ModuleOf_fcomplex let (x, y, z, kw1, A, T) = Main.Rebugger.getstored(id)\n    <body>\nend\n\nwhere Rebugger.getstored returns has been pre-loaded with the values that would have been set when you called fcomplex(x) in s above. This line can be edited and evaled at the REPL to analyze or improve fcomplex, or can be used for further stepin calls.\n\n\n\n\n\n"
},

{
    "location": "reference.html#Rebugger.prepare_caller_capture!",
    "page": "Developer reference",
    "title": "Rebugger.prepare_caller_capture!",
    "category": "function",
    "text": "callexpr = prepare_caller_capture!(io)\n\nGiven a buffer io representing a string and \"point\" (the seek position) set at a call expression, replace the call with one that stashes the function and arguments of the call.\n\nFor example, if io has contents\n\n<some code>\nif x > 0.5\n    ^fcomplex(x, 2; kw1=1.1)\n    <more code>\n\nwhere in the above ^ indicates position(s) (\"point\"), rewrite this as\n\n<some code>\nif x > 0.5\n    Main.Rebugger.stashed[] = (fcomplex, (x, 2), (kw1=1.1,))\n    throw(Rebugger.StopException())\n    <more code>\n\n(Keyword arguments do not affect dispatch and hence are not stashed.) Consequently, if this is evaled and execution reaches \"^\", it causes the arguments of the call to be placed in Rebugger.stashed.\n\ncallexpr is the original (unmodified) expression specifying the call, i.e., fcomplex(x, 2; kw1=1.1) in this case.\n\nThis does the buffer-preparation for caller capture. For callee capture, see method_capture_from_callee, and stepin which puts these two together.\n\n\n\n\n\n"
},

{
    "location": "reference.html#Rebugger.method_capture_from_callee",
    "page": "Developer reference",
    "title": "Rebugger.method_capture_from_callee",
    "category": "function",
    "text": "uuid = method_capture_from_callee(method; overwrite::Bool=false)\n\nCreate a version of method that stores its inputs in Main.Rebugger.stored. For a method\n\nfunction fcomplex(x::A, y=1, z=\"\"; kw1=3.2) where A<:AbstractArray{T} where T\n    <body>\nend\n\nif overwrite=false, this generates a new method\n\nfunction hidden_fcomplex(x::A, y=1, z=\"\"; kw1=3.2) where A<:AbstractArray{T} where T\n    Main.Rebugger.stored[uuid] = Main.Rebugger.Stored(fcomplex, (:x, :y, :z, :kw1, :A, :T), deepcopy((x, y, z, kw1, A, T)))\n    throw(StopException())\nend\n\n(If a uuid already exists for method from a previous call to method_capture_from_callee, it will simply be returned.)\n\nWith overwrite=true, there are two differences:\n\nit replaces fcomplex rather than defining hidden_fcomplex\nrather than throwing StopException, it re-inserts <body> after the line performing storage\n\nThe returned uuid can be used for accessing the stored data.\n\n\n\n\n\n"
},

{
    "location": "reference.html#Rebugger.signature_names!",
    "page": "Developer reference",
    "title": "Rebugger.signature_names!",
    "category": "function",
    "text": "fname, argnames, kwnames, parameternames = signature_names!(sigex::Expr)\n\nReturn the function name fname and names given to its arguments, keyword arguments, and parameters, as specified by the method signature-expression sigex.\n\nsigex will be modified if some of the arguments are unnamed.\n\nExamples\n\njulia> Rebugger.signature_names!(:(complexargs(w::Ref{A}, @nospecialize(x::Integer), y, z::String=\"\"; kwarg::Bool=false, kw2::String=\"\", kwargs...) where A <: AbstractArray{T,N} where {T,N}))\n(:complexargs, (:w, :x, :y, :z), (:kwarg, :kw2, :kwargs), (:A, :T, :N))\n\njulia> ex = :(myzero(::Float64));     # unnamed argument\n\njulia> Rebugger.signature_names!(ex)\n(:myzero, (:__Float64_1,), (), ())\n\njulia> ex\n:(myzero(__Float64_1::Float64))\n\n\n\n\n\n"
},

{
    "location": "reference.html#Capturing-arguments-1",
    "page": "Developer reference",
    "title": "Capturing arguments",
    "category": "section",
    "text": "Rebugger.stepin\nRebugger.prepare_caller_capture!\nRebugger.method_capture_from_callee\nRebugger.signature_names!"
},

{
    "location": "reference.html#Rebugger.capture_stacktrace",
    "page": "Developer reference",
    "title": "Rebugger.capture_stacktrace",
    "category": "function",
    "text": "uuids = capture_stacktrace(mod, command)\n\nExecute command in module mod. command must throw an error. Then instrument the methods in the stacktrace so that their input variables are stored in Rebugger.stored. After storing the inputs, restore the original methods.\n\nSince this requires two evals of command, usage should be limited to deterministic expressions that always result in the same call chain.\n\n\n\n\n\n"
},

{
    "location": "reference.html#Rebugger.pregenerated_stacktrace",
    "page": "Developer reference",
    "title": "Rebugger.pregenerated_stacktrace",
    "category": "function",
    "text": "usrtrace, defs = pregenerated_stacktrace(trace, topname=:eval_noinfo)\n\nGenerate a list of methods usrtrace and their corresponding definition-expressions defs from a stacktrace. Not all methods can be looked up, but this attempts to resolve, e.g., keyword-handling methods and so on.\n\n\n\n\n\n"
},

{
    "location": "reference.html#Rebugger.linerange",
    "page": "Developer reference",
    "title": "Rebugger.linerange",
    "category": "function",
    "text": "r = linerange(expr, offset=0)\n\nCompute the range of lines occupied by expr. Returns nothing if no line statements can be found.\n\n\n\n\n\n"
},

{
    "location": "reference.html#Capturing-stacktrace-1",
    "page": "Developer reference",
    "title": "Capturing stacktrace",
    "category": "section",
    "text": "Rebugger.capture_stacktrace\nRebugger.pregenerated_stacktrace\nRebugger.linerange"
},

{
    "location": "reference.html#Rebugger.getstored",
    "page": "Developer reference",
    "title": "Rebugger.getstored",
    "category": "function",
    "text": "args_and_types = Rebugger.getstored(uuid)\n\nRetrieve the values of stored arguments and type-parameters from the store specified uuid. This makes a copy of values, so as to be safe for repeated execution of methods that modify their inputs.\n\n\n\n\n\n"
},

{
    "location": "reference.html#Utilities-1",
    "page": "Developer reference",
    "title": "Utilities",
    "category": "section",
    "text": "Rebugger.getstored"
},

]}
