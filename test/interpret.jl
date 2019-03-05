using Rebugger, CodeTracking, Test

@testset "Interpret" begin
    m = @which Tuple((1,2))
    def = definition(m)
    linenos, line1, methlines = Rebugger.expression_lines(m)
    @test length(linenos) == length(methlines)
    @test issorted(linenos)
    @test linenos[end] >= maximum(CodeTracking.linerange(def))
end
