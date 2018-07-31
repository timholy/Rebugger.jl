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

    @testset "Reporting methods" begin
        def = quote
            function complexargs(x::A, y=1, str="1.0"; kw1=Float64, kw2=7) where A<:AbstractArray{T} where T
                return (x .+ y, parse(kw1, str), kw2)
            end
        end
        f = Core.eval(RebuggerTesting, def)
        @test f([8,9]) == ([9,10], 1.0, 7)
        m = collect(methods(f))[end]
        Rebugger.reporting_method(m, def, 1; trunc=false)
        @test f([8,9], 2, "13"; kw1=Int, kw2=0) == ([10,11], 13, 0)
        @test Rebugger.stack[1][2:end] == ((:x, :y, :str, :kw1, :kw2, :A, :T), ([8,9], 2, "13", Int, 0, Vector{Int}, Int))
        @test f([8,9]) == ([9,10], 1.0, 7)
        @test Rebugger.stack[1][2:end] == ((:x, :y, :str, :kw1, :kw2, :A, :T), ([8,9], 1, "1.0", Float64, 7, Vector{Int}, Int))
        empty!(Rebugger.stack)
        m = collect(methods(f))[end]
        Rebugger.reporting_method(m, def, 1; trunc=true)
        @test_throws StopException f([8,9], 2, "13"; kw1=Int, kw2=0)

        def = quote
            modifies!(x) = (x[1] += 1; x)
        end
        f = Core.eval(RebuggerTesting, def)
        @test f([8,9]) == [9,9]
        m = collect(methods(f))[end]
        Rebugger.reporting_method(m, def, 1; trunc=false)
        @test f([8,9]) == [9,9]
        @test Rebugger.stack[1][2:end] == ((:x,), ([8,9],))  # check that it's the original value
    end
end
