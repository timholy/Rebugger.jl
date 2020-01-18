var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "#Introduction-to-Rebugger-1",
    "page": "Home",
    "title": "Introduction to Rebugger",
    "category": "section",
    "text": "Rebugger is an expression-level debugger for Julia. It has two modes of action:an \"interpret\" mode that lets you step through code, set breakpoints, and other manipulations common to \"typical\" debuggers;\nan \"edit\" mode that presents method bodies as objects for manipulation, allowing you to interactively play with the code at different stages of execution.The name \"Rebugger\" has 3 meanings:it is a REPL-based debugger (more on that below)\nit is the Revise-based debugger\nit supports repeated-execution debugging"
},

{
    "location": "#Installation-1",
    "page": "Home",
    "title": "Installation",
    "category": "section",
    "text": "Begin with(v1.0) pkg> add RebuggerYou can experiment with Rebugger with justjulia> using RebuggerIf you eventually decide you like Rebugger, you can optionally configure it so that it is always available (see Configuration)."
},

{
    "location": "#Keyboard-shortcuts-1",
    "page": "Home",
    "title": "Keyboard shortcuts",
    "category": "section",
    "text": "Most of Rebugger\'s functionality gets triggered by special keyboard shortcuts added to Julia\'s REPL. Unfortunately, different operating systems and desktop environments vary considerably in their key bindings, and it is possible that the default choices in Rebugger are already assigned other meanings on your platform. There does not appear to be any one set of choices that works on all platforms.The best strategy is to try the demos in Usage; if the default shortcuts are already taken on your platform, then you can easily configure Rebugger to use different bindings (see Configuration).Some platforms are known to require or benefit from special attention:"
},

{
    "location": "#macOS-1",
    "page": "Home",
    "title": "macOS",
    "category": "section",
    "text": "If you\'re on macOS, you may want to enable \"Use option as the Meta key\" in your Terminal settings to avoid the need to press Esc before each Rebugger command."
},

{
    "location": "#Ubuntu-1",
    "page": "Home",
    "title": "Ubuntu",
    "category": "section",
    "text": "The default meta key on some Ubuntu versions is left Alt, which is equivalent to Esc Alt on the default Gnome terminal emulator. However, even with this tip you may encounter problems because Rebugger\'s default key bindings may be assigned to activate menu options within the terminal window, and this appears not to be configurable. Affected users may wish to Customize keybindings."
},

{
    "location": "usage/#",
    "page": "Usage",
    "title": "Usage",
    "category": "page",
    "text": ""
},

{
    "location": "usage/#Usage-1",
    "page": "Usage",
    "title": "Usage",
    "category": "section",
    "text": "Rebugger works from Julia\'s native REPL prompt. Currently there are exactly three keybindings, which here will be described as:Meta-i, which maps to \"interpret\"\nMeta-e, which maps to \"enter\" or \"step in\"\nMeta-s, which maps to \"stacktrace\" (for commands that throw an error)Meta often maps to Esc, and if using Esc you should hit the two keys in sequence rather than simultaneously. For many users Alt (sometimes specifically Left-Alt, or Option on macs) may be more convenient, as it can be pressed simultaneously with the key.Of course, you may have configured Rebugger to use different key bindings (see Customize keybindings)."
},

{
    "location": "usage/#Interpret-mode-1",
    "page": "Usage",
    "title": "Interpret mode",
    "category": "section",
    "text": "Interpret mode simulates an IDE debugger at the REPL: rather than entering your commands into a special prompt, you use single keystrokes to quickly advance through the code.Let\'s start with an example:julia> using Rebugger\n\njulia> a = [4, 1, 3, 2];Now we\'re going to call sort, but don\'t hit enter:julia> sort(a)Instead, hit Meta-i (Esc-i, Alt-i, or option-i):interpret> sort(a)[ Info: tracking Base\n\nsort(v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n  v = [4, 1, 3, 2]\n 742  sort(v::AbstractVector; kws...) = begin\n 742          sort!(copymutable(v); kws...)\n          end\nThe message informs you that Revise (which is used by Rebugger) is now examining the code in Base to extract the definition of sort. There\'s a considerable pause the first time you do this, but later it should generally be faster.After the \"Info\" line, you can see the method you called printed on top. After that are the local variables of sort, which here is just the array you supplied. (You can see some screenshots below in the \"edit mode\" section that show these in color. The meaning is the same here.) The \"742\" indicates the line number of \"sort.jl\", where the sort method you\'re calling is defined. Finally, you\'ll see a representation of the definition itself. Rebugger typically shows you expressions rather than verbatim text; unlike the text in the original file,  this works equally well for @evaled functions and generated functions.The current line number is printed in yellow; here, that\'s both lines, since the original definition was written on a single line.We can learn about the possibilities by typing ?:Commands:\n  space: next line\n  enter: continue to next breakpoint or completion\n      →: step in to next call\n      ←: finish frame and return to caller\n      ↑: display the caller frame\n      ↓: display the callee frame\n      b: insert breakpoint at current line\n      c: insert conditional breakpoint at current line\n      r: remove breakpoint at current line\n      d: disable breakpoint at current line\n      e: enable breakpoint at current line\n      q: abort (returns nothing)\nsort(v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n  v = [4, 1, 3, 2]\n 742  sort(v::AbstractVector; kws...) = begin\n 742          sort!(copymutable(v); kws...)\n          endLet\'s try stepping in to the call: hit the right arrow, at which point you should seesort(v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n #sort#8(kws, ::Any, v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n  #sort#8 = Base.Sort.#sort#8\n  kws = Base.Iterators.Pairs{Union{},Union{},Tuple{},NamedTuple{(),Tuple{}}}()\n  @_3 = sort\n  v = [4, 1, 3, 2]\n 742  sort(v::AbstractVector; kws...) = begin\n 742          sort!(copymutable(v); kws...)\n          endWe\'re now in a \"hidden\" method #sort#8, generated automatically by Julia to handle keyword and/or optional arguments. This is what actually contains the main body of sort. You\'ll note the source expression hasn\'t changed, because it\'s generated from the same definition, but that some additional arguments (kws and the \"nameless argument\" @_3) have appeared.If we hit the right arrow again, we enter copymutable. Our interest is in stepping further into sort, so we\'re not going to bother walking through copymutable; hit left arrow, which finishes the current frame and returns to the caller. This should return you to #sort#8. Then hit the right arrow again and you should be here:sort(v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n #sort#8(kws, ::Any, v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n  sort!(v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:682\n   #sort!#7(alg::Base.Sort.Algorithm, lt, by, rev::Union{Nothing, Bool}, order::Base.Order.Ordering, ::Any, v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:682\n  #sort!#7 = Base.Sort.#sort!#7\n  alg = Base.Sort.QuickSortAlg()\n  lt = isless\n  by = identity\n  rev = nothing\n  order = Base.Order.ForwardOrdering()\n  @_7 = sort!\n  v = [4, 1, 3, 2]\n 681  function sort!(v::AbstractVector; alg::Algorithm=defalg(v), lt=isless, by=identity, re…\n 682      ordr = ord(lt, by, rev, order)\n 683      if ordr === Forward && (v isa Vector && eltype(v) <: Integer)\n 684          n = length(v)Now you can see many more arguments. To understand everything you\'re seeing, sometimes it may help to open the source file in an editor (hit \'o\' for open) for comparison.Note that long function bodies are truncated; you only see a few lines around the current execution point.Line 682 should be highlighted. Hit the space bar and you should advance to 683:sort(v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n #sort#8(kws, ::Any, v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n  sort!(v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:682\n   #sort!#7(alg::Base.Sort.Algorithm, lt, by, rev::Union{Nothing, Bool}, order::Base.Order.Ordering, ::Any, v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:682\n  #sort!#7 = Base.Sort.#sort!#7\n  alg = Base.Sort.QuickSortAlg()\n  lt = isless\n  by = identity\n  rev = nothing\n  order = Base.Order.ForwardOrdering()\n  @_7 = sort!\n  v = [4, 1, 3, 2]\n  ordr = Base.Order.ForwardOrdering()\n 681  function sort!(v::AbstractVector; alg::Algorithm=defalg(v), lt=isless, by=identity, re…\n 682      ordr = ord(lt, by, rev, order)\n 683      if ordr === Forward && (v isa Vector && eltype(v) <: Integer)\n 684          n = length(v)\n 685          if n > 1You can see that the code display also advanced by one line.Let\'s go forward one more line (hit space) and then hit b to insert a breakpoint:sort(v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n #sort#8(kws, ::Any, v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n  sort!(v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:682\n   #sort!#7(alg::Base.Sort.Algorithm, lt, by, rev::Union{Nothing, Bool}, order::Base.Order.Ordering, ::Any, v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:682\n  #sort!#7 = Base.Sort.#sort!#7\n  alg = Base.Sort.QuickSortAlg()\n  lt = isless\n  by = identity\n  rev = nothing\n  order = Base.Order.ForwardOrdering()\n  @_7 = sort!\n  v = [4, 1, 3, 2]\n  ordr = Base.Order.ForwardOrdering()\n  #temp# = true\n 682      ordr = ord(lt, by, rev, order)\n 683      if ordr === Forward && (v isa Vector && eltype(v) <: Integer)\nb684          n = length(v)\n 685          if n > 1\n 686              (min, max) = extrema(v)The b in the left column indicates an unconditional breakpoint; a c would indicate a conditional breakpoint.At this point, hit Enter to finish the entire command (you should see the result printed at the REPL). Now let\'s run it again, by going back in the REPL history (hit the up arrow) and then hitting Meta-i again:interpret> sort(a)\nsort(v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n  v = [4, 1, 3, 2]\n 742  sort(v::AbstractVector; kws...) = begin\n 742          sort!(copymutable(v); kws...)\n          endWe may be back at the beginning, but remember: we set a breakpoint. Hit Enter to let execution move forward:interpret> sort(a)\nsort(v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n #sort#8(kws, ::Any, v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:742\n  sort!(v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:682\n   #sort!#7(alg::Base.Sort.Algorithm, lt, by, rev::Union{Nothing, Bool}, order::Base.Order.Ordering, ::Any, v::AbstractArray{T,1} where T) in Base.Sort at sort.jl:682\n  #sort!#7 = Base.Sort.#sort!#7\n  alg = Base.Sort.QuickSortAlg()\n  lt = isless\n  by = identity\n  rev = nothing\n  order = Base.Order.ForwardOrdering()\n  @_7 = sort!\n  v = [4, 1, 3, 2]\n  ordr = Base.Order.ForwardOrdering()\n  #temp# = true\n 682      ordr = ord(lt, by, rev, order)\n 683      if ordr === Forward && (v isa Vector && eltype(v) <: Integer)\nb684          n = length(v)\n 685          if n > 1\n 686              (min, max) = extrema(v)We\'re right back at that breakpoint again.Let\'s illustrate another example, this time in the context of errors:julia> convert(UInt, -8)\nERROR: InexactError: check_top_bit(Int64, -8)\nStacktrace:\n [1] throw_inexacterror(::Symbol, ::Any, ::Int64) at ./boot.jl:583\n [2] check_top_bit at ./boot.jl:597 [inlined]\n [3] toUInt64 at ./boot.jl:708 [inlined]\n [4] Type at ./boot.jl:738 [inlined]\n [5] convert(::Type{UInt64}, ::Int64) at ./number.jl:7\n [6] top-level scope at none:0Rebugger re-exports JuliaInterpreter\'s breakpoint manipulation utilities. Let\'s turn on breakpoints any time an (uncaught) exception is thrown:julia> break_on(:error)Now repeat that convert line but hit Meta-i instead of Enter:interpret> convert(UInt, -8)\nconvert(::Type{T}, x::Number) where T<:Number in Base at number.jl:7\n  #unused# = UInt64\n  x = -8\n  T = UInt64\n 7  (convert(::Type{T}, x::Number) where T <: Number) = begin\n 7          T(x)\n        endNow if you hit Enter, you\'ll be at the place where the error was thrown:\ninterpret> convert(UInt, -8)\nconvert(::Type{T}, x::Number) where T<:Number in Base at number.jl:7\n UInt64(x::Union{Bool, Int32, Int64, UInt32, UInt64, UInt8, Int128, Int16, Int8, UInt128, UInt16}) in Core at boot.jl:738\n  toUInt64(x::Int64) in Core at boot.jl:708\n   check_top_bit(x) in Core at boot.jl:596\n    throw_inexacterror(f::Symbol, T, val) in Core at boot.jl:583\n  f = check_top_bit\n  T = Int64\n  val = -8\n 583  throw_inexacterror(f::Symbol, @nospecialize(T), val) = (@_noinline_meta; throw(Inexact…Try using the up and down arrows to navigate up and down the call stack. This doesn\'t change the notion of current execution point (that\'s still at that throw_inexacterror call above), but it does let you see where you came from.You can turn this off with break_off and clear all manually-set breakpoints with remove()."
},

{
    "location": "usage/#A-few-important-details-1",
    "page": "Usage",
    "title": "A few important details",
    "category": "section",
    "text": "There are some calls that you can\'t step into: most of these are the \"builtins,\" \"intrinsics,\" and \"ccalls\" that lie at Julia\'s lowest level. Here\'s an example from hitting Meta-i on show:interpret> show([1,2,4])\nshow(x) in Base at show.jl:313\n  x = [1, 2, 4]\n 313  show(x) = begin\n 313          show(stdout::IO, x)\n          end\nThat looks like a call you\'d want to step into. But if you hit the right arrow, apparently nothing happens. That\'s because the next statement is actually that type-assertion stdout::IO. typeassert is a builtin, and consequently not a call you can step into.When in doubt, just repeat the same keystroke; here, the second press of the right arrow takes you to the two-argument show method that you probably thought you were descending into."
},

{
    "location": "usage/#Edit-mode-1",
    "page": "Usage",
    "title": "Edit mode",
    "category": "section",
    "text": ""
},

{
    "location": "usage/#Stepping-in-1",
    "page": "Usage",
    "title": "Stepping in",
    "category": "section",
    "text": "Select the expression you want to step into by positioning \"point\" (your cursor) at the desired location in the command line:<img src=\"../images/stepin1.png\" width=\"160px\"/>It\'s essential that point is at the very first character of the expression, in this case on the s in show.note: Note\nDon\'t confuse the REPL\'s cursor with your mouse pointer. Your mouse is essentially irrelevant on the REPL; use arrow keys or the other navigation features of Julia\'s REPL.Now if you hit Meta-e, you should see something like this:<img src=\"../images/stepin2.png\" width=\"660px\"/>(If not, check Keyboard shortcuts and Customize keybindings.) The cyan \"Info\" line is an indication that the method you\'re stepping into is a function in Julia\'s Base module; this is shown by Revise (not Rebugger), and only happens once per session.The remaining lines correspond to the Rebugger header and user input. The magenta line tells you which method you are stepping into. Indented blue line(s) show the value(s) of any input arguments or type parameters.If you\'re following along, move your cursor to the next show call as illustrated above. Hit Meta-e again. You should see a new show method, this time with two input arguments.Now let\'s demonstrate another important display item: position point at the beginning of the _show_empty call and hit Meta-e. The display should now look like this:<img src=\"../images/stepin3.png\" width=\"690px\"/>This time, note the yellow/orange line: this is a warning message, and you should pay attention to these. (You might also see red lines, which are generally more serious \"errors.\") In this case execution never reached _show_empty, because it enters show_vector instead; if you moved your cursor there, you could trace execution more completely.You can edit these expressions to insert code to display variables or test changes to the code. As an experiment, try stepping into the show_vector call from the example above and adding @show limited to display a local variable\'s value:<img src=\"../images/stepin4.png\" width=\"800px\"/>note: Note\nWhen editing expressions, you can insert a blank line with Meta-Enter (i.e., Esc-Enter, Alt-Enter, or Option-Enter). See the many advanced features of Julia\'s REPL that allow you to efficiently edit these let-blocks.Having illustrated the importance of \"point\" and the various colors used for messages from Rebugger, to ensure readability the remaining examples will be rendered as text."
},

{
    "location": "usage/#Capturing-stacktraces-in-edit-mode-1",
    "page": "Usage",
    "title": "Capturing stacktraces in edit mode",
    "category": "section",
    "text": "For a quick demo, we\'ll use the Colors package (add it if you don\'t have it) and deliberately choose a method that will end in an error: we\'ll try to parse a string as a Hue, Saturation, Lightness (HSL) color, except we\'ll \"forget\" that hue cannot be expressed as a percentage and deliberately trigger an error:julia> using Colors\n\njulia> colorant\"hsl(80%, 20%, 15%)\"\nERROR: LoadError: hue cannot end in %\nStacktrace:\n [1] error(::String) at ./error.jl:33\n [2] parse_hsl_hue(::SubString{String}) at /home/tim/.julia/dev/Colors/src/parse.jl:26\n [3] _parse_colorant(::String) at /home/tim/.julia/dev/Colors/src/parse.jl:75\n [4] _parse_colorant at /home/tim/.julia/dev/Colors/src/parse.jl:112 [inlined]\n [5] parse(::Type{Colorant}, ::String) at /home/tim/.julia/dev/Colors/src/parse.jl:140\n [6] @colorant_str(::LineNumberNode, ::Module, ::Any) at /home/tim/.julia/dev/Colors/src/parse.jl:147\nin expression starting at REPL[3]:1To capture the stacktrace, type the last line again or hit the up arrow, but instead of pressing Enter, type Meta-s. After a short delay, you should see something like this:julia> colorant\"hsl(80%, 20%, 15%)\"\n┌ Warning: Tuple{getfield(Colors, Symbol(\"#@colorant_str\")),LineNumberNode,Module,Any} was not found, perhaps it was generated by code\n└ @ Revise ~/.julia/dev/Revise/src/Revise.jl:659\nCaptured elements of stacktrace:\n[1] parse_hsl_hue(num::AbstractString) in Colors at /home/tim/.julia/packages/Colors/4hvzi/src/parse.jl:25\n[2] _parse_colorant(desc::AbstractString) in Colors at /home/tim/.julia/packages/Colors/4hvzi/src/parse.jl:51\n[3] _parse_colorant(::Type{C}, ::Type{SUP}, desc::AbstractString) where {C<:Colorant, SUP} in Colors at /home/tim/.julia/packages/Colors/4hvzi/src/parse.jl:112\n[4] parse(::Type{C}, desc::AbstractString) where C<:Colorant in Colors at /home/tim/.julia/packages/Colors/4hvzi/src/parse.jl:140\nparse_hsl_hue(num::AbstractString) in Colors at /home/tim/.julia/packages/Colors/4hvzi/src/parse.jl:25\n  num = 80%\nrebug> @eval Colors let (num,) = Main.Rebugger.getstored(\"57dbc76a-0def-11e9-1dbf-ef97d29d2e25\")\n       begin\n           if num[end] == \'%\'\n               error(\"hue cannot end in %\")\n           else\n               return parse(Int, num, base=10)\n           end\n       end\n       end(Again, if this doesn\'t happen check Keyboard shortcuts and Customize keybindings.) You are in the method corresponding to [1] in the stacktrace. Now you can navigate with your up and down arrows to browse the captured stacktrace. For example, if you hit the up arrow twice, you will be in the method corresponding to [3]:julia> colorant\"hsl(80%, 20%, 15%)\"\n┌ Warning: Tuple{getfield(Colors, Symbol(\"#@colorant_str\")),LineNumberNode,Module,Any} was not found, perhaps it was generated by code\n└ @ Revise ~/.julia/dev/Revise/src/Revise.jl:659\nCaptured elements of stacktrace:\n[1] parse_hsl_hue(num::AbstractString) in Colors at /home/tim/.julia/packages/Colors/4hvzi/src/parse.jl:25\n[2] _parse_colorant(desc::AbstractString) in Colors at /home/tim/.julia/packages/Colors/4hvzi/src/parse.jl:51\n[3] _parse_colorant(::Type{C}, ::Type{SUP}, desc::AbstractString) where {C<:Colorant, SUP} in Colors at /home/tim/.julia/packages/Colors/4hvzi/src/parse.jl:112\n[4] parse(::Type{C}, desc::AbstractString) where C<:Colorant in Colors at /home/tim/.julia/packages/Colors/4hvzi/src/parse.jl:140\n[5] @colorant_str(__source__::LineNumberNode, __module__::Module, ex) in Colors at /home/tim/.julia/packages/Colors/4hvzi/src/parse.jl:146\n_parse_colorant(::Type{C}, ::Type{SUP}, desc::AbstractString) where {C<:Colorant, SUP} in Colors at /home/tim/.julia/packages/Colors/4hvzi/src/parse.jl:112\n  C = Colorant\n  SUP = Any\n  desc = hsl(80%, 20%, 15%)\nrebug> @eval Colors let (C, SUP, desc) = Main.Rebugger.getstored(\"57d9ebc0-0def-11e9-2ab0-e5d1e4c6e82d\")\n       begin\n           _parse_colorant(desc)\n       end\n       endYou can hit the down arrow and go back to earlier entries in the trace. Alternatively, you can pick any of these expressions to execute (hit Enter) or edit before execution. You can use the REPL history to test the results of many different changes to the same \"method\"; the \"method\" will be run with the same inputs each time.note: Note\nWhen point is at the end of the input, the up and down arrows step through the history. But if you move point into the method body (e.g., by using left-arrow), the up and down arrows move within the method body. If you\'ve entered edit mode, you can go back to history mode using PgUp and PgDn."
},

{
    "location": "usage/#Important-notes-1",
    "page": "Usage",
    "title": "Important notes",
    "category": "section",
    "text": ""
},

{
    "location": "usage/#\"Missing\"-methods-from-stacktraces-1",
    "page": "Usage",
    "title": "\"Missing\" methods from stacktraces",
    "category": "section",
    "text": "Sometimes, there\'s a large difference between the \"real\" stacktrace and the \"captured\" stacktrace:julia> using Pkg\n\njulia> Pkg.add(\"NoPkg\")\n  Updating registry at `~/.julia/registries/General`\n  Updating git-repo `https://github.com/JuliaRegistries/General.git`\nERROR: The following package names could not be resolved:\n * NoPkg (not found in project, manifest or registry)\nPlease specify by known `name=uuid`.\nStacktrace:\n [1] pkgerror(::String) at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/Types.jl:120\n [2] #ensure_resolved#42(::Bool, ::Function, ::Pkg.Types.EnvCache, ::Array{Pkg.Types.PackageSpec,1}) at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/Types.jl:890\n [3] #ensure_resolved at ./none:0 [inlined]\n [4] #add_or_develop#13(::Symbol, ::Bool, ::Base.Iterators.Pairs{Union{},Union{},Tuple{},NamedTuple{(),Tuple{}}}, ::Function, ::Pkg.Types.Context, ::Array{Pkg.Types.PackageSpec,1}) at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:59\n [5] #add_or_develop at ./none:0 [inlined]\n [6] #add_or_develop#12 at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:29 [inlined]\n [7] #add_or_develop at ./none:0 [inlined]\n [8] #add_or_develop#11(::Base.Iterators.Pairs{Symbol,Symbol,Tuple{Symbol},NamedTuple{(:mode,),Tuple{Symbol}}}, ::Function, ::Array{String,1}) at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:28\n [9] #add_or_develop at ./none:0 [inlined]\n [10] #add_or_develop#10 at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:27 [inlined]\n [11] #add_or_develop at ./none:0 [inlined]\n [12] #add#18 at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:69 [inlined]\n [13] add(::String) at /home/tim/src/julia-1.0/usr/share/julia/stdlib/v1.0/Pkg/src/API.jl:69\n [14] top-level scope at none:0\n\njulia> Pkg.add(\"NoPkg\")  # hit Meta-s here\n[1] pkgerror(msg::String...) in Pkg.Types at /home/tim/src/julia-1/usr/share/julia/stdlib/v1.1/Pkg/src/Types.jl:120\n[2] #ensure_resolved#72(registry::Bool, ::Any, env::Pkg.Types.EnvCache, pkgs::AbstractArray{Pkg.Types.PackageSpec,1}) in Pkg.Types at /home/tim/src/julia-1/usr/share/julia/stdlib/v1.1/Pkg/src/Types.jl:981\n[3] #add_or_develop#15(mode::Symbol, shared::Bool, kwargs, ::Any, ctx::Pkg.Types.Context, pkgs::Array{Pkg.Types.PackageSpec,1}) in Pkg.API at /home/tim/src/julia-1/usr/share/julia/stdlib/v1.1/Pkg/src/API.jl:34\n[4] #add_or_develop#12(kwargs, ::Any, pkg::Union{AbstractString, PackageSpec}) in Pkg.API at /home/tim/src/julia-1/usr/share/julia/stdlib/v1.1/Pkg/src/API.jl:28\n[5] add(args...) in Pkg.API at /home/tim/src/julia-1/usr/share/julia/stdlib/v1.1/Pkg/src/API.jl:59\npkgerror(msg::String...) in Pkg.Types at /home/tim/src/julia-1/usr/share/julia/stdlib/v1.1/Pkg/src/Types.jl:120\n  msg = (\"The following package names could not be resolved:\\n * NoPkg (not found in project, manifest or registry)\\nPlease specify by known `name=uuid`.\",)\nrebug> @eval Pkg.Types let (msg,) = Main.Rebugger.getstored(\"1ac42628-4b15-11e9-28e7-33f71870bf31\")\n       begin\n           throw(PkgError(join(msg)))\n       end\n       endNote that only five methods got captured but the stacktrace is much longer. Most of these methods, however, say \"inlined\" with line number 0. Rebugger has no way of finding such methods. However, you can enter (i.e., Meta-e) such methods from one that is higher in the stack trace."
},

{
    "location": "usage/#Modified-\"signatures\"-1",
    "page": "Usage",
    "title": "Modified \"signatures\"",
    "category": "section",
    "text": "Some \"methods\" you see in the let block on the command line will have their \"signatures\" slightly modified. For example:julia> dest = zeros(3);\n\njulia> copyto!(dest, 1:4)\nERROR: BoundsError: attempt to access 3-element Array{Float64,1} at index [1, 2, 3, 4]\nStacktrace:\n [1] copyto!(::IndexLinear, ::Array{Float64,1}, ::IndexLinear, ::UnitRange{Int64}) at ./abstractarray.jl:728\n [2] copyto!(::Array{Float64,1}, ::UnitRange{Int64}) at ./abstractarray.jl:723\n [3] top-level scope at none:0\n\njulia> copyto!(dest, 1:4)  # hit Meta-s here\nCaptured elements of stacktrace:\n[1] copyto!(::IndexStyle, dest::AbstractArray, ::IndexStyle, src::AbstractArray) in Base at abstractarray.jl:727\n[2] copyto!(dest::AbstractArray, src::AbstractArray) in Base at abstractarray.jl:723\ncopyto!(::IndexStyle, dest::AbstractArray, ::IndexStyle, src::AbstractArray) in Base at abstractarray.jl:727\n  __IndexStyle_1 = IndexLinear()\n  dest = [0.0, 0.0, 0.0]\n  __IndexStyle_2 = IndexLinear()\n  src = 1:4\nrebug> @eval Base let (__IndexStyle_1, dest, __IndexStyle_2, src) = Main.Rebugger.getstored(\"21a8ab94-a228-11e8-0563-256e39b3996e\")\n       begin\n           (destinds, srcinds) = (LinearIndices(dest), LinearIndices(src))\n           isempty(srcinds) || (checkbounds(Bool, destinds, first(srcinds)) && checkbounds(Bool, destinds, last(srcinds)) || throw(BoundsError(dest, srcinds)))\n           @inbounds for i = srcinds\n                   dest[i] = src[i]\n               end\n           return dest\n       end\n       endNote that this copyto! method contains two anonymous arguments annotated ::IndexStyle. Rebugger will make up names for these arguments (here __IndexStyle_1 and __IndexStyle_2). While these will be distinct from one another, Rebugger does not check whether they conflict with any internal names.note: Note\nThis example illustrates a second important point: you may have noticed that this one was considerably slower to print. That\'s because capturing stacktraces overwrites the methods involved. Since copyto! is widely used, this forces recompilation of a lot of methods in Base.In contrast with capturing stacktraces, stepping in (Meta-e) does not overwrite methods, so is sometimes preferred. And of course, interpret mode (Meta-i) also doesn\'t overwrite methods."
},

{
    "location": "config/#",
    "page": "Configuration",
    "title": "Configuration",
    "category": "page",
    "text": ""
},

{
    "location": "config/#Configuration-1",
    "page": "Configuration",
    "title": "Configuration",
    "category": "section",
    "text": ""
},

{
    "location": "config/#Run-on-REPL-startup-1",
    "page": "Configuration",
    "title": "Run on REPL startup",
    "category": "section",
    "text": "If you decide you like Rebugger, you can add lines such as the following to your ~/.julia/config/startup.jl file:atreplinit() do repl\n    try\n        @eval using Revise\n        @async Revise.wait_steal_repl_backend()\n    catch\n        @warn \"Could not load Revise.\"\n    end\n\n    try\n        @eval using Rebugger\n    catch\n        @warn \"Could not load Rebugger.\"\n    end\nend"
},

{
    "location": "config/#Customize-keybindings-1",
    "page": "Configuration",
    "title": "Customize keybindings",
    "category": "section",
    "text": "As described in Keyboard shortcuts, it\'s possible that Rebugger\'s default keybindings don\'t work for you. You can work around problems by changing them to keys of your own choosing.To add your own keybindings, use Rebugger.add_keybindings(action=keybinding, ...). This can be done during a running Rebugger session. Here is an example that maps the \"step in\" action to the key \"F6\" and \"capture stacktrace\" to \"F7\"julia> Rebugger.add_keybindings(stepin=\"\\e[17~\", stacktrace=\"\\e[18~\")To make your keybindings permanent, change the \"Rebugger\" section of your startup.jl file to something like:atreplinit() do repl\n    ...\n\n    try\n        @eval using Rebugger\n        # Activate Rebugger\'s key bindings\n        Rebugger.keybindings[:stepin] = \"\\e[17~\"      # Add the keybinding F6 to step into a function.\n        Rebugger.keybindings[:stacktrace] = \"\\e[18~\"  # Add the keybinding F7 to capture a stacktrace.\n    catch\n        @warn \"Could not load Rebugger.\"\n    end\nendnote: Note\nBesides the obvious, one reason to insert the keybindings into the startup.jl, has to do with the order in which keybindings are added to the REPL and whether any \"stale\" bindings that might have side effects are still present. Doing it before atreplinit means that there won\'t be any stale bindings.But how to find out the cryptic string that corresponds to the keybinding you want? Use Julia\'s read() function:julia> str = read(stdin, String)\n^[[17~\"\\e[17~\"  # Press F6, followed by Ctrl+D, Ctrl+D\n\njulia> str\n\"\\e[17~\"After calling read(), press the keybinding that you want. Then, press Ctrl+D twice to terminate the input. The value of str is the cryptic string you are looking for.If you want to know whether your key binding is already taken, the REPL documentation as well as any documentation on your operating system, desktop environment, and/or terminal program can be useful references."
},

{
    "location": "limitations/#",
    "page": "Limitations",
    "title": "Limitations",
    "category": "page",
    "text": ""
},

{
    "location": "limitations/#Limitations-1",
    "page": "Limitations",
    "title": "Limitations",
    "category": "section",
    "text": "Rebugger is in the early stages of development, and users should currently expect bugs (please do report them). Nevertheless it may be of net benefit for some users.Here are some known shortcomings:Rebugger only has access to code tracked by Revise. To ensure that scripts are tracked, use includet(filename) to include-and-track. (See Revise\'s documentation.) For stepping into Julia\'s stdlibs, currently you need a source-build of Julia.\nYou cannot step into methods defined at the REPL.\nFor now you can\'t step into constructors (it tries to step into (::Type{T}))\nThere are occasional glitches in the display. (For brave souls who want to help fix these, see HeaderREPLs.jl)\nRebugger runs best in Julia 1.0. While it should run on Julia 0.7, a local-scope deprecation can cause some problems. If you want 0.7 because of its deprecation warnings and are comfortable building Julia, consider building it at commit f08f3b668d222042425ce20a894801b385c2b1e2, which removed the local-scope deprecation but leaves most of the other deprecation warnings from 0.7 still in place.\nIf you start deving a package that you had already loaded, you need to restart your sessionAnother important point (not particularly specific to Rebugger) is that repeatedly executing code that modifies some global state can lead to unexpected side effects. Rebugger works best on methods whose behavior is determined solely by their input arguments."
},

{
    "location": "internals/#",
    "page": "How Rebugger works",
    "title": "How Rebugger works",
    "category": "page",
    "text": ""
},

{
    "location": "internals/#How-Rebugger-works-1",
    "page": "How Rebugger works",
    "title": "How Rebugger works",
    "category": "section",
    "text": "Rebugger traces execution through use of expression-rewriting and Julia\'s ordinary try/catch control-flow. It maintains internal storage that allows other methods to \"deposit\" their arguments (a store) or temporarily stash the function and arguments of a call."
},

{
    "location": "internals/#Implementation-of-\"step-in\"-1",
    "page": "How Rebugger works",
    "title": "Implementation of \"step in\"",
    "category": "section",
    "text": "Rebugger makes use of the buffer containing user input: not just its contents, but also the position of \"point\" (the seek position) to indicate the specific call expression targeted for stepping in.For example, if a buffer has contents    # <some code>\n    if x > 0.5\n        ^fcomplex(x, 2; kw1=1.1)\n        # <more code>where in the above ^ indicates \"point,\" Rebugger uses a multi-stage process to enter fcomplex with appropriate arguments:First, it carries out caller capture to determine which function is being called at point, and with which arguments. The main goal here is to be able to then use which to determine the specific method.\nOnce armed with the specific method, it then carries out callee capture to obtain all the inputs to the method. For simple methods this may be redundant with caller capture, but callee capture can also obtain the values of default arguments, keyword arguments, and type parameters.\nFinally, Rebugger rewrites the REPL command-line buffer with a suitably-modified version of the body of the called method, so that the user can inspect, run, and manipulate it."
},

{
    "location": "internals/#Caller-capture-1",
    "page": "How Rebugger works",
    "title": "Caller capture",
    "category": "section",
    "text": "The original expression above is rewritten as    # <some code>\n    if x > 0.5\n        Main.Rebugger.stashed[] = (fcomplex, (x, 2), (kw1=1.1,))\n        throw(Rebugger.StopException())\n        # <more code>Note that the full context of the original expression is preserved, thereby ensuring that we do not have to be concerned about not having the appropriate local scope for the arguments to the call of fcomplex. However, rather than actually calling fcomplex, this expression \"stashes\" the arguments and function in a temporary store internal to Rebugger. It then throws an exception type specifically crafted to signal that the expression executed and exited as expected.This expression is then evaluated inside a block    try\n        Core.eval(Main, caller_capture_expression)\n        throw(StashingFailed())\n    catch err\n        err isa StashingFailed && rethrow(err)\n        if !(err isa StopException)\n            throw(EvalException(content(buffer), err))\n        end\n    endNote that this looks for the StopException; this is considered the normal execution path. If the StopException is never hit, it means evaluation never reached the expression marked by \"point\" and thus leads to a StashingFailed exception. Any other error results in an EvalException, usually triggered by other errors in the block of code.Assuming the StopException is hit, we then proceed to callee capture."
},

{
    "location": "internals/#Callee-capture-1",
    "page": "How Rebugger works",
    "title": "Callee capture",
    "category": "section",
    "text": "Rebugger removes the function and arguments from Rebugger.stashed[] and then uses which to determine the specific method called. It then asks Revise for the expression that defines the method. It then analyzes the signature to determine the full complement of inputs and creates a new method that stores them. For example, if the applicable method of fcomplex is given by    function fcomplex(x::A, y=1, z=\"\"; kw1=3.2) where A<:AbstractArray{T} where T\n        # <body>\n    endthen Rebugger generates a new method    function hidden_fcomplex(x::A, y=1, z=\"\"; kw1=3.2) where A<:AbstractArray{T} where T\n        Main.Rebugger.stored[uuid] = Main.Rebugger.Stored(fcomplex, (:x, :y, :z, :kw1, :A, :T), deepcopy((x, y, z, kw1, A, T)))\n        throw(StopException())\n    endThis method is then called from inside another try/catch block that again checks for a StopException. This results in the complete set of inputs being stored, a more \"permanent\" form of preservation than stashing, which only lasts for the gap between caller and callee capture. If one has the appropriate uuid, one can then extract these values at will from storage using Rebugger.getstored."
},

{
    "location": "internals/#Generating-the-new-buffer-contents-(the-let-expression)-1",
    "page": "How Rebugger works",
    "title": "Generating the new buffer contents (the let expression)",
    "category": "section",
    "text": "Once callee capture is complete, the user can re-execute any components of the called method as desired. To make this easier, Rebugger replaces the contents of the buffer with a line that looks like this:@eval <ModuleOf_fcomplex> let (x, y, z, kw1, A, T) = Main.Rebugger.getstored(\"0123abc...\")\n    # <body>\nendThe @eval makes sure that the block will be executed within the module in which fcomplex is defined; as a consequence it will have access to all the unexported methods, etc., that fcomplex itself has. The let block ensures that these variables do not conflict with other objects that may be defined in ModuleOf_fcomplex. The values are unloaded from the store (making copies, in case fcomplex modifies its inputs) and then execution proceeds into body.The user can then edit the buffer at will."
},

{
    "location": "internals/#Implementation-of-\"catch-stacktrace\"-1",
    "page": "How Rebugger works",
    "title": "Implementation of \"catch stacktrace\"",
    "category": "section",
    "text": "In contrast with \"step in,\" when catching a stacktrace Rebugger does not know the specific methods that will be used in advance of making the call. Consequently, Rebugger has to execute the call twice:the first call is used to obtain a stacktrace\nThe trace is analyzed to obtain the specific methods, which are then replaced with versions that place inputs in storage; see Callee capture, with the differences\nthe original method is (temporarily) overwritten by one that executes the store\nthis \"storing\" method also includes the full method body\nThese two changes ensure that the \"call chain\" is not broken.\na second call (recreating the same error, for functions that have deterministic execution) is then made to store all the arguments at each captured stage of the stacktrace.\nfinally, the original methods are restored."
},

{
    "location": "reference/#",
    "page": "Developer reference",
    "title": "Developer reference",
    "category": "page",
    "text": ""
},

{
    "location": "reference/#Developer-reference-1",
    "page": "Developer reference",
    "title": "Developer reference",
    "category": "section",
    "text": ""
},

{
    "location": "reference/#Rebugger.stepin",
    "page": "Developer reference",
    "title": "Rebugger.stepin",
    "category": "function",
    "text": "stepin(s)\n\nGiven a buffer s representing a string and \"point\" (the seek position) set at a call expression, replace the contents of the buffer with a let expression that wraps the body of the callee.\n\nFor example, if s has contents\n\n<some code>\nif x > 0.5\n    ^fcomplex(x)\n    <more code>\n\nwhere in the above ^ indicates position(s) (\"point\"), and if the definition of fcomplex is\n\nfunction fcomplex(x::A, y=1, z=\"\"; kw1=3.2) where A<:AbstractArray{T} where T\n    <body>\nend\n\nrewrite s so that its contents are\n\n@eval ModuleOf_fcomplex let (x, y, z, kw1, A, T) = Main.Rebugger.getstored(id)\n    <body>\nend\n\nwhere Rebugger.getstored returns has been pre-loaded with the values that would have been set when you called fcomplex(x) in s above. This line can be edited and evaled at the REPL to analyze or improve fcomplex, or can be used for further stepin calls.\n\n\n\n\n\n"
},

{
    "location": "reference/#Rebugger.prepare_caller_capture!",
    "page": "Developer reference",
    "title": "Rebugger.prepare_caller_capture!",
    "category": "function",
    "text": "callexpr = prepare_caller_capture!(io)\n\nGiven a buffer io representing a string and \"point\" (the seek position) set at a call expression, replace the call with one that stashes the function and arguments of the call.\n\nFor example, if io has contents\n\n<some code>\nif x > 0.5\n    ^fcomplex(x, 2; kw1=1.1)\n    <more code>\n\nwhere in the above ^ indicates position(s) (\"point\"), rewrite this as\n\n<some code>\nif x > 0.5\n    Main.Rebugger.stashed[] = (fcomplex, (x, 2), (kw1=1.1,))\n    throw(Rebugger.StopException())\n    <more code>\n\n(Keyword arguments do not affect dispatch and hence are not stashed.) Consequently, if this is evaled and execution reaches \"^\", it causes the arguments of the call to be placed in Rebugger.stashed.\n\ncallexpr is the original (unmodified) expression specifying the call, i.e., fcomplex(x, 2; kw1=1.1) in this case.\n\nThis does the buffer-preparation for caller capture. For callee capture, see method_capture_from_callee, and stepin which puts these two together.\n\n\n\n\n\n"
},

{
    "location": "reference/#Rebugger.method_capture_from_callee",
    "page": "Developer reference",
    "title": "Rebugger.method_capture_from_callee",
    "category": "function",
    "text": "uuid = method_capture_from_callee(method; overwrite::Bool=false)\n\nCreate a version of method that stores its inputs in Main.Rebugger.stored. For a method\n\nfunction fcomplex(x::A, y=1, z=\"\"; kw1=3.2) where A<:AbstractArray{T} where T\n    <body>\nend\n\nif overwrite=false, this generates a new method\n\nfunction hidden_fcomplex(x::A, y=1, z=\"\"; kw1=3.2) where A<:AbstractArray{T} where T\n    Main.Rebugger.stored[uuid] = Main.Rebugger.Stored(fcomplex, (:x, :y, :z, :kw1, :A, :T), deepcopy((x, y, z, kw1, A, T)))\n    throw(StopException())\nend\n\n(If a uuid already exists for method from a previous call to method_capture_from_callee, it will simply be returned.)\n\nWith overwrite=true, there are two differences:\n\nit replaces fcomplex rather than defining hidden_fcomplex\nrather than throwing StopException, it re-inserts <body> after the line performing storage\n\nThe returned uuid can be used for accessing the stored data.\n\n\n\n\n\n"
},

{
    "location": "reference/#Rebugger.signature_names!",
    "page": "Developer reference",
    "title": "Rebugger.signature_names!",
    "category": "function",
    "text": "fname, argnames, kwnames, parameternames = signature_names!(sigex::Expr)\n\nReturn the function name fname and names given to its arguments, keyword arguments, and parameters, as specified by the method signature-expression sigex.\n\nsigex will be modified if some of the arguments are unnamed.\n\nExamples\n\njulia> Rebugger.signature_names!(:(complexargs(w::Ref{A}, @nospecialize(x::Integer), y, z::String=\"\"; kwarg::Bool=false, kw2::String=\"\", kwargs...) where A <: AbstractArray{T,N} where {T,N}))\n(:complexargs, (:w, :x, :y, :z), (:kwarg, :kw2, :kwargs), (:A, :T, :N))\n\njulia> ex = :(myzero(::Float64));     # unnamed argument\n\njulia> Rebugger.signature_names!(ex)\n(:myzero, (:__Float64_1,), (), ())\n\njulia> ex\n:(myzero(__Float64_1::Float64))\n\n\n\n\n\n"
},

{
    "location": "reference/#Capturing-arguments-1",
    "page": "Developer reference",
    "title": "Capturing arguments",
    "category": "section",
    "text": "Rebugger.stepin\nRebugger.prepare_caller_capture!\nRebugger.method_capture_from_callee\nRebugger.signature_names!"
},

{
    "location": "reference/#Rebugger.capture_stacktrace",
    "page": "Developer reference",
    "title": "Rebugger.capture_stacktrace",
    "category": "function",
    "text": "uuids = capture_stacktrace(mod, command)\n\nExecute command in module mod. command must throw an error. Then instrument the methods in the stacktrace so that their input variables are stored in Rebugger.stored. After storing the inputs, restore the original methods.\n\nSince this requires two evals of command, usage should be limited to deterministic expressions that always result in the same call chain.\n\n\n\n\n\n"
},

{
    "location": "reference/#Rebugger.pregenerated_stacktrace",
    "page": "Developer reference",
    "title": "Rebugger.pregenerated_stacktrace",
    "category": "function",
    "text": "usrtrace, defs = pregenerated_stacktrace(trace, topname=:capture_stacktrace)\n\nGenerate a list of methods usrtrace and their corresponding definition-expressions defs from a stacktrace. Not all methods can be looked up, but this attempts to resolve, e.g., keyword-handling methods and so on.\n\n\n\n\n\n"
},

{
    "location": "reference/#Rebugger.linerange",
    "page": "Developer reference",
    "title": "Rebugger.linerange",
    "category": "function",
    "text": "r = linerange(expr, offset=0)\n\nCompute the range of lines occupied by expr. Returns nothing if no line statements can be found.\n\n\n\n\n\n"
},

{
    "location": "reference/#Capturing-stacktrace-1",
    "page": "Developer reference",
    "title": "Capturing stacktrace",
    "category": "section",
    "text": "Rebugger.capture_stacktrace\nRebugger.pregenerated_stacktrace\nRebugger.linerange"
},

{
    "location": "reference/#Rebugger.clear",
    "page": "Developer reference",
    "title": "Rebugger.clear",
    "category": "function",
    "text": "Rebugger.clear()\n\nClear internal data. This deletes storage associated with stored variables, but also forces regeneration of capture methods, which can be handy while debugging Rebugger itself.\n\n\n\n\n\n"
},

{
    "location": "reference/#Rebugger.getstored",
    "page": "Developer reference",
    "title": "Rebugger.getstored",
    "category": "function",
    "text": "args_and_types = Rebugger.getstored(uuid)\n\nRetrieve the values of stored arguments and type-parameters from the store specified uuid. This makes a copy of values, so as to be safe for repeated execution of methods that modify their inputs.\n\n\n\n\n\n"
},

{
    "location": "reference/#Utilities-1",
    "page": "Developer reference",
    "title": "Utilities",
    "category": "section",
    "text": "Rebugger.clear\nRebugger.getstored"
},

]}
