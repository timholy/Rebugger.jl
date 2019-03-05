using Rebugger, CodeTracking, Test, InteractiveUtils

@testset "Interpret" begin
    for m in (@which(Tuple((1,2))),
              which(Base.show_vector, Tuple{IO,Any}),
              which(Rebugger.interpret, Tuple{Any}),
             )
        def = definition(m)
        linenos, line1, methlines = Rebugger.expression_lines(m)
        @test length(linenos) == length(methlines)
        @test issorted(linenos)
        @test linenos[end] >= maximum(CodeTracking.linerange(def))
    end
end
