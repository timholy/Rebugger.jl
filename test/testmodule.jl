module RebuggerTesting

const cbdata1 = Ref{Any}(nothing)
const cbdata2 = Ref{Any}(nothing)

function foo end

snoop0()             = snoop1("Spy")
snoop1(word)         = snoop2(word, "on")
snoop2(word1, word2) = snoop3(word1, word2, "arguments")
snoop3(word1, word2, word3::T; adv="simply") where T = error("oops")

end
