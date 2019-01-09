module RebuggerTesting

const cbdata1 = Ref{Any}(nothing)
const cbdata2 = Ref{Any}(nothing)

# Do not alter the line number at which `foo` occurs
foo(x, y) = nothing

snoop0()             = snoop1("Spy")
snoop1(word)         = snoop2(word, "on")
snoop2(word1, word2) = snoop3(word1, word2, "arguments")
snoop3(word1, word2, word3::T; adv="simply", morekws...) where T = error("oops")

kwvarargs(x; kw1=1, kwargs...)  = kwvarargs2(x; kw1=kw1, kwargs...)
kwvarargs2(x; kw1=0, passthrough=true) = (x, kw1, passthrough)

destruct(x, (a, b), y) = a

struct HasValue
    x::Float64
end
const hv_test = HasValue(11.1)

(hv::HasValue)(str::String) = hv.x

@inline kwfuncerr(y) = error("stop")
@noinline kwfuncmiddle(x::T, y::Integer=1; kw1="hello", kwargs...) where T = kwfuncerr(y)
@inline kwfunctop(x; kwargs...) = kwfuncmiddle(x, 2; kwargs...)

function apply(f, args...)
    kwvarargs(f)
    f(args...)
end

calldo() = apply(2, 3, 4) do x, y, z
    snoop3(x, y, z)
end

end

module RBT2

using ..RebuggerTesting

bar(::Int) = 5
RebuggerTesting.foo() = bar(1)

end
