module RebuggerTesting

const cbdata1 = Ref{Any}(nothing)
const cbdata2 = Ref{Any}(nothing)

foo(x, y) = nothing

snoop0()             = snoop1("Spy")
snoop1(word)         = snoop2(word, "on")
snoop2(word1, word2) = snoop3(word1, word2, "arguments")
snoop3(word1, word2, word3::T; adv="simply", morekws...) where T = error("oops")

kwvarargs(x; kw1=1, kwargs...)  = kwvarargs2(x; kw1=kw1, kwargs...)
kwvarargs2(x; kw1=0, passthrough=true) = (x, kw1, passthrough)

struct HasValue
    x::Float64
end
const hv_test = HasValue(11.1)

(hv::HasValue)(str::String) = hv.x

end

module RBT2

using ..RebuggerTesting

bar(::Int) = 5
RebuggerTesting.foo() = bar(1)

end
