using Rebugger
using Rebugger: StopException
using Test

if !isdefined(Main, :RebuggerTesting)
    Revise.track("testmodule.jl")   # so the source code here gets loaded
end

@testset "Rebugger" begin
    @testset "Callee variable capture" begin
        def = quote
            function complexargs(x::A, y=1, str="1.0"; kw1=Float64, kw2=7) where A<:AbstractArray{T} where T
                return (x .+ y, parse(kw1, str), kw2)
            end
        end
        f = Core.eval(RebuggerTesting, def)
        @test f([8,9]) == ([9,10], 1.0, 7)
        m = collect(methods(f))[end]
        Rebugger.method_capture_from_callee(m, def, 1; trunc=false)
        @test f([8,9], 2, "13"; kw1=Int, kw2=0) == ([10,11], 13, 0)
        @test Rebugger.stack[1][2:end] == ((:x, :y, :str, :kw1, :kw2, :A, :T), ([8,9], 2, "13", Int, 0, Vector{Int}, Int))
        @test f([8,9]) == ([9,10], 1.0, 7)
        @test Rebugger.stack[1][2:end] == ((:x, :y, :str, :kw1, :kw2, :A, :T), ([8,9], 1, "1.0", Float64, 7, Vector{Int}, Int))
        empty!(Rebugger.stack)
        m = collect(methods(f))[end]
        Rebugger.method_capture_from_callee(m, def, 1; trunc=true)
        @test_throws StopException f([8,9], 2, "13"; kw1=Int, kw2=0)

        def = quote
            modifies!(x) = (x[1] += 1; x)
        end
        f = Core.eval(RebuggerTesting, def)
        @test f([8,9]) == [9,9]
        m = collect(methods(f))[end]
        Rebugger.method_capture_from_callee(m, def, 1; trunc=false)
        @test f([8,9]) == [9,9]
        @test Rebugger.stack[1][2:end] == ((:x,), ([8,9],))  # check that it's the original value
    end

    @testset "Caller buffer capture and insertion" begin
        function run_insertion(str, atstr)
            RebuggerTesting.cbdata1[] = RebuggerTesting.cbdata2[] = Rebugger.stashed[] = nothing
            io = IOBuffer()
            idx = findfirst(atstr, str)
            print(io, str)
            seek(io, first(idx)-1)
            storestring, stashstring = Rebugger.capture_from_caller!(io)
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
        run_insertion(str, "foo")
        @test RebuggerTesting.cbdata1[] == 1
        @test RebuggerTesting.cbdata2[] == nothing
        @test Rebugger.stashed[] == (RebuggerTesting.foo, (12, 13))
        str = """
        for i = 1:5
            error("not caught")
            foo(12, 13; akw="modified")
        end
        """
        @test_throws ErrorException("not caught") run_insertion(str, "foo")
    end

    @testset "Step in" begin
        function run_stepin(str, atstr)
            io = IOBuffer()
            idx = findfirst(atstr, str)
            print(io, str)
            seek(io, first(idx)-1)
            Rebugger.stepin!(io)
            String(take!(io))
        end

        empty!(Rebugger.stack)
        str = "RebuggerTesting.snoop0()"
        cmd = run_stepin(str, str)
        @test cmd == """
        @eval Main.RebuggerTesting let () = Main.Rebugger.stack[1][3]
        begin
            snoop1("Spy")
        end
        end"""
        cmd = run_stepin(cmd, "snoop1")
        @test cmd == """
        @eval Main.RebuggerTesting let (word) = Main.Rebugger.stack[2][3]
        begin
            snoop2(word, "on")
        end
        end"""
        cmd = run_stepin(cmd, "snoop2")
        @test cmd == """
        @eval Main.RebuggerTesting let (word1, word2) = Main.Rebugger.stack[3][3]
        begin
            snoop3(word1, word2, "arguments")
        end
        end"""

        empty!(Rebugger.stack)
        str = "RebuggerTesting.kwvarargs(1)"
        cmd = run_stepin(str, str)
        @test cmd == """
        @eval Main.RebuggerTesting let (x, kw1, kwargs) = Main.Rebugger.stack[1][3]
        begin
            kwvarargs2(x; kw1=kw1, kwargs...)
        end
        end"""
        cmd = run_stepin(cmd, "kwvarargs2")

        empty!(Rebugger.stack)
        str = "RebuggerTesting.kwvarargs(1; passthrough=false)"
        cmd = run_stepin(str, str)
        @test cmd == """
        @eval Main.RebuggerTesting let (x, kw1, kwargs) = Main.Rebugger.stack[1][3]
        begin
            kwvarargs2(x; kw1=kw1, kwargs...)
        end
        end"""
        cmd = run_stepin(cmd, "kwvarargs2")
    end

    @testset "Capture stacktrace" begin
        empty!(Rebugger.stack)
        mktemp() do path, iostacktrace
            redirect_stderr(iostacktrace) do
                Rebugger.capture_stacktrace(RebuggerTesting, :(snoop0()))
            end
            flush(iostacktrace)
            str = read(path, String)
            @test occursin("snoop3", str)
        end
        @test Rebugger.stack[1][2:3] == ((), ())
        @test Rebugger.stack[2][2:3] == ((:word,), ("Spy",))
        @test Rebugger.stack[3][2:3] == ((:word1, :word2), ("Spy", "on"))
        @test Rebugger.stack[4][2:3] == ((:word1, :word2, :word3, :adv, :morekws, :T), ("Spy", "on", "arguments", "simply", Iterators.Pairs(NamedTuple(), ()), String))
        empty!(Rebugger.stack)
        @test_throws ErrorException("oops") RebuggerTesting.snoop0()
        @test isempty(Rebugger.stack)
    end
end
