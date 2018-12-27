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
    "text": "Rebugger is an expression-level debugger for Julia. It has no ability to interact with or manipulate call stacks (see ASTInterpreter2), but it can trace execution via the manipulation of Julia expressions.The name \"Rebugger\" has 3 meanings:it is a REPL-based debugger (more on that below)\nit is the Revise-based debugger\nit supports repeated-execution \"surface\" debuggingRebugger is an unusual debugger with a novel work-flow paradigm. With most debuggers, you enter some special mode that lets the user \"dive into the code,\" but what you are allowed to do while in this special mode may be limited. In contrast, Rebugger brings the code along with its input arguments to the user, presenting them both for inspection, analysis, and editing in the (mostly) normal Julia interactive command line. As a consequence, you can:test different modifications to the code or arguments without being forced to exit debug mode and save your file\nrun the same chosen block of code repeatedly (perhaps with different modifications each time) without having to repeat any of the \"setup\" work that might have been necessary to get to some deeply nested method in the original call stack. In other words, Rebugger brings \"internal\" methods to the surface.\nrun any desired command that helps you understand the nature of a bug. For example, if you\'ve already loaded MyFavoritePlottingPackage in your session, then when debugging you can (transiently) add Main.MyFavoritePlottingPackage.plot(x, y) as a line of the method-body you are currently analyzing, and you should see a plot of the requested variables.Rebugger exploits the Julia REPL\'s history capabilities to simulate the stacktrace-navigation features of graphical debuggers. Thus Rebugger offers a command-line experience that is more closely aligned with graphical debuggers than the traditional s, n, up, c commands of a console debugger."
},

{
    "location": "index.html#Installation-1",
    "page": "Home",
    "title": "Installation",
    "category": "section",
    "text": "Begin with(v1.0) pkg> add RebuggerYou can experiment with Rebugger with justjulia> using RebuggerIf you eventually decide you like Rebugger, you can optionally configure it so that it is always available (see Configuration)."
},

{
    "location": "index.html#Keyboard-shortcuts-1",
    "page": "Home",
    "title": "Keyboard shortcuts",
    "category": "section",
    "text": "Most of Rebugger\'s functionality gets triggered by special keyboard shortcuts added to Julia\'s REPL. Unfortunately, different operating systems and desktop environments vary considerably in their key bindings, and it is possible that the default choices in Rebugger are already assigned other meanings on your platform. There does not appear to be any one set of choices that works on all platforms.The best strategy is to try the demos in Usage; if the default shortcuts are already taken on your platform, then you can easily configure Rebugger to use different bindings (see Configuration).Some platforms are known to require or benefit from special attention:"
},

{
    "location": "index.html#macOS-1",
    "page": "Home",
    "title": "macOS",
    "category": "section",
    "text": "If you\'re on macOS, you may want to enable \"Use option as the Meta key\" in your Terminal settings to avoid the need to press Esc before each Rebugger command."
},

{
    "location": "index.html#Ubuntu-1",
    "page": "Home",
    "title": "Ubuntu",
    "category": "section",
    "text": "The default meta key on Ubuntu is left Alt, which is equivalent to Esc Alt on the default Gnome terminal emulator. However, even with this tip you may encounter problems because Rebugger\'s default key bindings may be assigned to activate menu options within the terminal window, and this appears not to be configurable. As a consequence Ubuntu users will very likely need to Customize keybindings."
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
    "text": "Rebugger works from Julia\'s native REPL prompt. Currently there are exactly two keybindings, which here will be described as:Meta-e, which maps to \"enter\" or \"step in\"\nMeta-s, which maps to \"stacktrace\" (for commands that throw an error)Meta often maps to Esc, and if using Esc you should hit the two keys in sequence rather than simultaneously. For many users Alt (sometimes specifically Left-Alt, or Option on macs) may be more convenient, as it can be pressed simultaneously with the key.Of course, you may have configured Rebugger to use different key bindings (see Customize keybindings)."
},

{
    "location": "usage.html#Stepping-in-1",
    "page": "Usage",
    "title": "Stepping in",
    "category": "section",
    "text": "Select the expression you want to step into by positioning \"point\" (your cursor) at the desired location in the command line:<img src=\"images/stepin1.png\" width=\"200px\"/>It\'s essential that point is at the very first character of the expression, in this case on the s in show. Now if you hit Meta-e, you should see something like this:<img src=\"images/stepin2.png\" width=\"822px\"/>(If not, check Keyboard shortcuts and Customize keybindings.) The cyan \"Info\" line is an indication that the method you\'re stepping into is a function in Julia\'s Base module; this is shown by Revise (not Rebugger), and only happens once per session.The remaining lines correspond to the Rebugger header and user input. The magenta line tells you which method you are stepping into. Indented blue line(s) show the value(s) of any input arguments or type parameters.If you\'re following along, move your cursor to the next show call as illustrated above. Hit Meta-e again. You should see a new show method, this time with two input arguments.Now let\'s demonstrate another important display item: position your cursor at the beginning of the _show_empty call and hit Meta-e. The display should now look like this:<img src=\"images/stepin3.png\" width=\"859px\"/>This time, note the yellow/orange line: this is a warning message, and you should pay attention to these. (You might also see red lines, which are generally more serious \"errors.\") In this case execution never reached _show_empty, because it enters show_vector instead; if you moved your cursor there, you could trace execution more completely.Having illustrated the importance of \"point\" and the various colors used for messages from Rebugger, to ensure readability the remaining examples will be rendered as text."
},

{
    "location": "usage.html#Capturing-stacktraces-1",
    "page": "Usage",
    "title": "Capturing stacktraces",
    "category": "section",
    "text": "For a quick demo, we\'ll use the Colors package (add it if you don\'t have it) and deliberately choose a method that will end in an error: we\'ll try to parse a string as a Hue, Saturation, Lightness (HSL) color, except we\'ll \"forget\" that hue cannot be expressed as a percentage and deliberately trigger an error:julia> using Colors\n\njulia> colorant\"hsl(80%, 20%, 15%)\"\nERROR: LoadError: hue cannot end in %\nStacktrace:\n [1] error(::String) at ./error.jl:33\n [2] parse_hsl_hue(::SubString{String}) at /home/tim/.julia/dev/Colors/src/parse.jl:26\n [3] _parse_colorant(::String) at /home/tim/.julia/dev/Colors/src/parse.jl:75\n [4] _parse_colorant at /home/tim/.julia/dev/Colors/src/parse.jl:112 [inlined]\n [5] parse(::Type{Colorant}, ::String) at /home/tim/.julia/dev/Colors/src/parse.jl:140\n [6] @colorant_str(::LineNumberNode, ::Module, ::Any) at /home/tim/.julia/dev/Colors/src/parse.jl:147\nin expression starting at REPL[3]:1To capture the stacktrace, type the last line again or hit the up arrow, but instead of pressing enter type Meta-s. After a short delay, you should see something like this:julia> colorant\"hsl(80%, 20%, 15%)\"\n┌ Warning: Tuple{getfield(Colors, Symbol(\"#@colorant_str\")),LineNumberNode,Module,Any} was not found, perhaps it was generated by code\n└ @ Revise ~/.julia/dev/Revise/src/Revise.jl:614\nCaptured elements of stacktrace:\n[1] parse_hsl_hue(num::AbstractString) in Colors at /home/tim/.julia/dev/Colors/src/parse.jl:25\n[2] _parse_colorant(desc::AbstractString) in Colors at /home/tim/.julia/dev/Colors/src/parse.jl:51\n[3] parse(::Type{C}, desc::AbstractString) where C<:Colorant in Colors at /home/tim/.julia/dev/Colors/src/parse.jl:140\nparse_hsl_hue(num::AbstractString) in Colors at /home/tim/.julia/dev/Colors/src/parse.jl:25\n  num = 80%\nrebug> @eval Colors let (num,) = Main.Rebugger.getstored(\"c592f0a4-a226-11e8-1002-fd2731558606\")\n       begin\n           if num[end] == \'%\'\n               error(\"hue cannot end in %\")\n           else\n               return parse(Int, num, base=10)\n           end\n       end\n       end(Again, if this doesn\'t happen check Keyboard shortcuts and Customize keybindings.) Now you can navigate with your up and down arrows to browse the captured stacktrace. You can pick any of these expressions to execute (hit Enter) or edit before execution. For example you could add @show commands to examine intermediate variables or test out different ways to fix a bug. You can use the REPL history to test the results of many different changes to the same \"method\"; the \"method\" will be run with the same inputs each time."
},

{
    "location": "usage.html#Important-notes-1",
    "page": "Usage",
    "title": "Important notes",
    "category": "section",
    "text": ""
},

{
    "location": "usage.html#\"Missing\"-methods-from-stacktraces-1",
    "page": "Usage",
    "title": "\"Missing\" methods from stacktraces",
    "category": "section",
    "text": "In the example above, you may have noticed the warning about the @colorant_str macro being omitted from the \"captured\" (interactive) expressions comprising the stacktrace. Macros are not traced. Also notice that the inlined method does not appear in the captured stacktrace. However, you can enter an inlined method using \"step in,\" starting from the method above it in the stacktrace.When many methods use keyword arguments, the apparent difference between the \"real\" stacktrace and the \"captured\" stacktrace can be quite dramatic:julia> using Pkg\n\njulia> Pkg.add(\"NoPkg\")\n  Updating registry at `~/.julia/registries/General`\n  Updating git-repo `https://github.com/JuliaRegistries/General.git`\nERROR: The following package names could not be resolved:\n * NoPkg (not found in project, manifest or registry)\nPlease specify by known `name=uuid`.\nStacktrace:\n [1] pkgerror(::String) at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/Types.jl:120\n [2] #ensure_resolved#42(::Bool, ::Function, ::Pkg.Types.EnvCache, ::Array{Pkg.Types.PackageSpec,1}) at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/Types.jl:890\n [3] #ensure_resolved at ./none:0 [inlined]\n [4] #add_or_develop#13(::Symbol, ::Bool, ::Base.Iterators.Pairs{Union{},Union{},Tuple{},NamedTuple{(),Tuple{}}}, ::Function, ::Pkg.Types.Context, ::Array{Pkg.Types.PackageSpec,1}) at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:59\n [5] #add_or_develop at ./none:0 [inlined]\n [6] #add_or_develop#12 at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:29 [inlined]\n [7] #add_or_develop at ./none:0 [inlined]\n [8] #add_or_develop#11(::Base.Iterators.Pairs{Symbol,Symbol,Tuple{Symbol},NamedTuple{(:mode,),Tuple{Symbol}}}, ::Function, ::Array{String,1}) at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:28\n [9] #add_or_develop at ./none:0 [inlined]\n [10] #add_or_develop#10 at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:27 [inlined]\n [11] #add_or_develop at ./none:0 [inlined]\n [12] #add#18 at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:69 [inlined]\n [13] add(::String) at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:69\n [14] top-level scope at none:0\n\njulia> Pkg.add(\"NoPkg\")  # hit Meta-s here\nCaptured elements of stacktrace:\n[1] pkgerror(msg::String...) in Pkg.Types at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/Types.jl:120\n[2] ensure_resolved(env::Pkg.Types.EnvCache, pkgs::AbstractArray{Pkg.Types.PackageSpec,1}) in Pkg.Types at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/Types.jl:860\n[3] add_or_develop(ctx::Pkg.Types.Context, pkgs::Array{Pkg.Types.PackageSpec,1}) in Pkg.API at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:32\n[4] add_or_develop(pkgs::Array{String,1}) in Pkg.API at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:28\n[5] add(args...) in Pkg.API at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:69\npkgerror(msg::String...) in Pkg.Types at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/Types.jl:120\n  msg = (\"The following package names could not be resolved:\\n * NoPkg (not found in project, manifest or registry)\\nPlease specify by known `name=uuid`.\",)\nrebug> @eval Pkg.Types let (msg,) = Main.Rebugger.getstored(\"b5c899c2-a228-11e8-0877-d102334a9f65\")\n       begin\n           throw(PkgError(join(msg)))\n       end\n       endNote that only five methods got captured but the stacktrace is much longer. Most of these methods, however, start with #, an indication that they are generated methods rather than ones that appear in the source code. The interactive stacktrace visits only those methods that appear in the original source code.note: Note\nPkg is one of Julia\'s standard libraries, and to step into or trace Julia\'s stdlibs you must build Julia from source."
},

{
    "location": "usage.html#Modified-\"signatures\"-1",
    "page": "Usage",
    "title": "Modified \"signatures\"",
    "category": "section",
    "text": "Some \"methods\" you see in the let block on the command line will have their \"signatures\" slightly modified. For example:julia> dest = zeros(3);\n\njulia> copyto!(dest, 1:4)\nERROR: BoundsError: attempt to access 3-element Array{Float64,1} at index [1, 2, 3, 4]\nStacktrace:\n [1] copyto!(::IndexLinear, ::Array{Float64,1}, ::IndexLinear, ::UnitRange{Int64}) at ./abstractarray.jl:728\n [2] copyto!(::Array{Float64,1}, ::UnitRange{Int64}) at ./abstractarray.jl:723\n [3] top-level scope at none:0\n\njulia> copyto!(dest, 1:4)  # hit Meta-s here\nCaptured elements of stacktrace:\n[1] copyto!(::IndexStyle, dest::AbstractArray, ::IndexStyle, src::AbstractArray) in Base at abstractarray.jl:727\n[2] copyto!(dest::AbstractArray, src::AbstractArray) in Base at abstractarray.jl:723\ncopyto!(::IndexStyle, dest::AbstractArray, ::IndexStyle, src::AbstractArray) in Base at abstractarray.jl:727\n  __IndexStyle_1 = IndexLinear()\n  dest = [0.0, 0.0, 0.0]\n  __IndexStyle_2 = IndexLinear()\n  src = 1:4\nrebug> @eval Base let (__IndexStyle_1, dest, __IndexStyle_2, src) = Main.Rebugger.getstored(\"21a8ab94-a228-11e8-0563-256e39b3996e\")\n       begin\n           (destinds, srcinds) = (LinearIndices(dest), LinearIndices(src))\n           isempty(srcinds) || (checkbounds(Bool, destinds, first(srcinds)) && checkbounds(Bool, destinds, last(srcinds)) || throw(BoundsError(dest, srcinds)))\n           @inbounds for i = srcinds\n                   dest[i] = src[i]\n               end\n           return dest\n       end\n       endNote that this copyto! method contains two anonymous arguments annotated ::IndexStyle. Rebugger will make up names for these arguments (here __IndexStyle_1 and __IndexStyle_2). While these will be distinct from one another, Rebugger does not check whether they conflict with any internal names.note: Note\nThis example illustrates a second important point: you may have noticed that this one was considerably slower to print. That\'s because capturing stacktraces overwrites the methods involved. Since copyto! is widely used, this forces recompilation of a lot of methods in Base.In contrast with capturing stacktraces, stepping in does not overwrite methods, so is sometimes preferred."
},

{
    "location": "config.html#",
    "page": "Configuration",
    "title": "Configuration",
    "category": "page",
    "text": ""
},

{
    "location": "config.html#Configuration-1",
    "page": "Configuration",
    "title": "Configuration",
    "category": "section",
    "text": ""
},

{
    "location": "config.html#Run-on-REPL-startup-1",
    "page": "Configuration",
    "title": "Run on REPL startup",
    "category": "section",
    "text": "If you decide you like Rebugger, you can add lines such as the following to your ~/.julia/config/startup.jl file:atreplinit() do repl\n    try\n        @eval using Revise\n        @async Revise.wait_steal_repl_backend()\n    catch\n        @warn \"Could not load Revise.\"\n    end\n\n    try\n        @eval using Rebugger\n    catch\n        @warn \"Could not load Rebugger.\"\n    end\nend"
},

{
    "location": "config.html#Customize-keybindings-1",
    "page": "Configuration",
    "title": "Customize keybindings",
    "category": "section",
    "text": "As described in Keyboard shortcuts, it\'s possible that Rebugger\'s default keybindings don\'t work for you. You can work around problems by changing them to keys of your own choosing.To add your own keybindings, use Rebugger.add_keybindings(action=keybinding, ...). This can be done during a running Rebugger session. Here is an example that maps the \"step in\" action to the key \"F6\" and \"capture stacktrace\" to \"F7\"julia> Rebugger.add_keybindings(stepin=\"\\e[17~\", stacktrace=\"\\e[18~\")To make your keybindings permanent, change the \"Rebugger\" section of your startup.jl file to something like:atreplinit() do repl\n    ...\n\n    try\n        @eval using Rebugger\n        # Activate Rebugger\'s key bindings\n        Rebugger.keybindings[:stepin] = \"\\e[17~\"      # Add the keybinding F6 to step into a function.\n        Rebugger.keybindings[:stacktrace] = \"\\e[18~\"  # Add the keybinding F7 to capture a stacktrace.\n    catch\n        @warn \"Could not load Rebugger.\"\n    end\nendnote: Note\nBesides the obvious, one reason to insert the keybindings into the startup.jl, has to do with the order in which keybindings are added to the REPL and whether any \"stale\" bindings that might have side effects are still present. Doing it before atreplinit means that there won\'t be any stale bindings.But how to find out the cryptic string that corresponds to the keybinding you want? Use Julia\'s read() function:julia> str = read(stdin, String)\n^[[17~\"\\e[17~\"  # Press F6, followed by Ctrl+D, Ctrl+D\n\njulia> str\n\"\\e[17~\"After calling read(), press the keybinding that you want. Then, press Ctrl+D twice to terminate the input. The value of str is the cryptic string you are looking for.If you want to know whether your key binding is already taken, the REPL documentation as well as any documentation on your operating system, desktop environment, and/or terminal program can be useful references."
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
    "text": "Rebugger is in the early stages of development, and users should currently expect bugs (please do report them). Nevertheless it may be of net benefit for some users.Here are some known shortcomings:Rebugger only has access to code tracked by Revise. To ensure that scripts are tracked, use includet(filename) to include-and-track. (See Revise\'s documentation.) For stepping into Julia\'s stdlibs, currently you need a source-build of Julia.\nYou cannot step into methods defined at the REPL.\nFor now you can\'t step into constructors (it tries to step into (::Type{T}))\nThere are occasional glitches in the display. (For brave souls who want to help fix these, see HeaderREPLs.jl)\nRebugger runs best in Julia 1.0. While it should run on Julia 0.7, a local-scope deprecation can cause some problems. If you want 0.7 because of its deprecation warnings and are comfortable building Julia, consider building it at commit f08f3b668d222042425ce20a894801b385c2b1e2, which removed the local-scope deprecation but leaves most of the other deprecation warnings from 0.7 still in place.\nIf you start deving a package that you had already loaded, you need to restart your sessionAnother important point (not particularly specific to Rebugger) is that repeatedly executing code that modifies some global state can lead to unexpected side effects. Rebugger works best on methods whose behavior is determined solely by their input arguments."
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
    "text": "Rebugger makes use of the buffer containing user input: not just its contents, but also the position of \"point\" (the seek position) to indicate the specific call expression targeted for stepping in.For example, if a buffer has contents    # <some code>\n    if x > 0.5\n        ^fcomplex(x, 2; kw1=1.1)\n        # <more code>where in the above ^ indicates \"point,\" Rebugger uses a multi-stage process to enter fcomplex with appropriate arguments:First, it carries out caller capture to determine which function is being called at point, and with which arguments. The main goal here is to be able to then use which to determine the specific method.\nOnce armed with the specific method, it then carries out callee capture to obtain all the inputs to the method. For simple methods this may be redundant with caller capture, but callee capture can also obtain the values of default arguments, keyword arguments, and type parameters.\nFinally, Rebugger rewrites the REPL command-line buffer with a suitably-modified version of the body of the called method, so that the user can inspect, run, and manipulate it."
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
    "text": "Once callee capture is complete, the user can re-execute any components of the called method as desired. To make this easier, Rebugger replaces the contents of the buffer with a line that looks like this:@eval <ModuleOf_fcomplex> let (x, y, z, kw1, A, T) = Main.Rebugger.getstored(\"0123abc...\")\n    # <body>\nendThe @eval makes sure that the block will be executed within the module in which fcomplex is defined; as a consequence it will have access to all the unexported methods, etc., that fcomplex itself has. The let block ensures that these variables do not conflict with other objects that may be defined in ModuleOf_fcomplex. The values are unloaded from the store (making copies, in case fcomplex modifies its inputs) and then execution proceeds into body.The user can then edit the buffer at will."
},

{
    "location": "internals.html#Implementation-of-\"catch-stacktrace\"-1",
    "page": "How Rebugger works",
    "title": "Implementation of \"catch stacktrace\"",
    "category": "section",
    "text": "In contrast with \"step in,\" when catching a stacktrace Rebugger does not know the specific methods that will be used in advance of making the call. Consequently, Rebugger has to execute the call twice:the first call is used to obtain a stacktrace\nThe trace is analyzed to obtain the specific methods, which are then replaced with versions that place inputs in storage; see Callee capture, with the differences\nthe original method is (temporarily) overwritten by one that executes the store\nthis \"storing\" method also includes the full method body\nThese two changes ensure that the \"call chain\" is not broken.\na second call (recreating the same error, for functions that have deterministic execution) is then made to store all the arguments at each captured stage of the stacktrace.\nfinally, the original methods are restored."
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
    "text": "usrtrace, defs = pregenerated_stacktrace(trace, topname=:capture_stacktrace)\n\nGenerate a list of methods usrtrace and their corresponding definition-expressions defs from a stacktrace. Not all methods can be looked up, but this attempts to resolve, e.g., keyword-handling methods and so on.\n\n\n\n\n\n"
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
    "location": "reference.html#Rebugger.clear",
    "page": "Developer reference",
    "title": "Rebugger.clear",
    "category": "function",
    "text": "Rebugger.clear()\n\nClear internal data. This deletes storage associated with stored variables, but also forces regeneration of capture methods, which can be handy while debugging Rebugger itself.\n\n\n\n\n\n"
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
    "text": "Rebugger.clear\nRebugger.getstored"
},

]}
