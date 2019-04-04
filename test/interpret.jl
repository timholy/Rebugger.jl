using Rebugger, JuliaInterpreter
using CodeTracking, Revise, Test, InteractiveUtils

if !isdefined(Main, :fixable1)
    includet("interpret_script.jl")
end

@testset "Expression-printing and line numbers" begin
    for m in (@which(Tuple((1,2))),
              which(Base.show_vector, Tuple{IO,Any}),
              which(Rebugger.interpret, Tuple{Any}),
             )
        def = definition(m)
        linenos, line1, methlines = Rebugger.expression_lines(m)
        @test length(linenos) == length(methlines)
        @test issorted(skipmissing(linenos))
        @test maximum(skipmissing(linenos)) >= maximum(CodeTracking.linerange(def))
    end

    # Line number fill-in
    for f in (fixable1, fixable2, fixable3)
        m = first(methods(f))
        linenos, line1, methlines = Rebugger.expression_lines(m)
        @test count(ismissing, linenos) == 1  # only the final end is ambiguous
    end
    linenos, line1, methlines = Rebugger.expression_lines(first(methods(unfixable1)))
    @test count(ismissing, linenos) == 3

    # Generated functions
    for ndims = 2:3
        frame = JuliaInterpreter.enter_call(call_generated1, ndims)
        pc, n = frame.pc, JuliaInterpreter.nstatements(frame.framecode)
        while pc < n-1
            frame, pc = debug_command(frame, :se)
        end
        frame, pc = debug_command(frame, :si)
        linenos, line1, methlines = Rebugger.expression_lines(frame)
        @test length(methlines) == 3 && strip(methlines[2]) == string(Expr(:tuple, ntuple(i->:val, ndims)...))
    end

    # Unparsed methods
    frame = JuliaInterpreter.enter_call(getline, LineNumberNode(0, Symbol("fake.jl")))
    frame, pc = debug_command(frame, :si)
    m = JuliaInterpreter.scopeof(frame)
    if m.file == Symbol("sysimg.jl")  # sysimg.jl is excluded from Revise tracking
        linenos, line1, methlines = Rebugger.expression_lines(frame)
        @test linenos == [m.line]
    end

    # Internal macros (issue #63)
    frame = JuliaInterpreter.enter_call(f63)
    deflines = Rebugger.expression_lines(frame)
    frame, pc = debug_command(frame, :n)
    io = IOBuffer()
    Rebugger.show_code(io, frame, deflines, 0)
    str = String(take!(io))
    @test occursin("y = 7", str)
end
