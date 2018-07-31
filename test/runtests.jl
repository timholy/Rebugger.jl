using Rebugger
using Rebugger: StopException, KeywordArg
using Test

module RebuggerTesting

const cbdata1 = Ref{Any}(nothing)
const cbdata2 = Ref{Any}(nothing)

function foo end

end

@testset "Rebugger" begin
    @testset "Buffer capture and insertion" begin
        function run_insertion(str, atstr)
            RebuggerTesting.cbdata1[] = RebuggerTesting.cbdata2[] = Rebugger.record[] = nothing
            io = IOBuffer()
            idx = findfirst(atstr, str)
            print(io, str)
            seek(io, first(idx)-1)
            Rebugger.insert_capture!(io)
            str′ = String(take!(io))
            expr′ = Meta.parse(str′)
            try
                Core.eval(RebuggerTesting, expr′)
            catch err
                isa(err, StopException) || rethrow(err)
            end
        end

        str = """
        for i = 1:5
            cbdata1[] = i
            foo(12, 13; akw="modified")
            cbdata2[] = i
        end
        """
        @test run_insertion(str, "foo")
        @test RebuggerTesting.cbdata1[] == 1
        @test RebuggerTesting.cbdata2[] == nothing
        @test Rebugger.record[] == (RebuggerTesting.foo, (12, 13, KeywordArg(:akw, "modified")))
        str = """
        for i = 1:5
            error("not caught")
            foo(12, 13; akw="modified")
        end
        """
        @test_throws ErrorException("not caught") run_insertion(str, "foo")
    end
end
