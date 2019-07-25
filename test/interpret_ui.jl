# This was copied from Debugger.jl and then modified

using TerminalRegressionTests, Rebugger, Revise, CodeTracking
using HeaderREPLs, REPL
using Test

includet("my_gcd.jl")

function run_terminal_test(cmd, validation, commands)
    function compare_replace(em, target; replace=nothing)
        # Compare two buffer, skipping over the equivalent of key=>rep replacement
        # However, because of potential differences in wrapping we don't explicitly
        # perform the replacement; instead, we make the comparison tolerant of difference
        # `\n`.
        buf = IOBuffer()
        decoratorbuf = IOBuffer()
        TerminalRegressionTests.VT100.dump(buf, decoratorbuf, em)
        outbuf = take!(buf)
        success = true
        if replace !== nothing
            output = String(outbuf)
            key, rep = replace
            idxkey = findfirst(key, target)
            iout, itgt = firstindex(output), firstindex(target)
            outlast, tgtlast = lastindex(output), lastindex(target)
            lrep = length(rep)
            while success && iout <= outlast && itgt <= tgtlast
                if itgt == first(idxkey)
                    itgt += length(key)
                    for c in rep
                        cout = output[iout]
                        while c != cout && cout == '\n'
                            iout = nextind(output, iout)
                            cout = output[iout]
                        end
                        if c != cout
                            success = false
                            break
                        end
                        iout = nextind(output, iout)
                    end
                else
                    cout, ctgt = output[iout], target[itgt]
                    success = cout == ctgt
                    iout, itgt = nextind(output, iout), nextind(target, itgt)
                end
            end
            success && iout > outlast && itgt > tgtlast && return true
        end
        outbuf == codeunits(target) && return true
        open("failed.out","w") do f
            write(f, output)
        end
        open("expected.out","w") do f
            write(f, target)
        end
        error("Test failed. Expected result written to expected.out,
            actual result written to failed.out")
    end

    dirpath = joinpath(@__DIR__, "ui", "v$(VERSION.major).$(VERSION.minor)")
    isdir(dirpath) || mkpath(dirpath)
    filepath = joinpath(dirpath, validation)
    # Fix the path of gcd to match the current running version of Julia
    gcdfile, gcdline = whereis(@which my_gcd(10, 20))
    cmp(a, b, decorator) = compare_replace(a, b; replace="****" => gcdfile*':'*string(gcdline))
    TerminalRegressionTests.automated_test(cmp, filepath, commands) do emuterm
    # TerminalRegressionTests.create_automated_test(filepath, commands) do emuterm
        main_repl = REPL.LineEditREPL(emuterm, true)
        main_repl.interface = REPL.setup_interface(main_repl)
        main_repl.specialdisplay = REPL.REPLDisplay(main_repl)
        main_repl.mistate = REPL.LineEdit.init_state(REPL.terminal(main_repl), main_repl.interface)
        iprompt, eprompt = Rebugger.rebugrepl_init(main_repl, true)
        repl = iprompt.repl
        s = repl.mistate
        s.current_mode = iprompt
        repl.t = emuterm
        REPL.LineEdit.edit_clear(s)
        REPL.LineEdit.edit_insert(s, cmd)
        Rebugger.interpret(s)
    end
end

CTRL_C = "\x3"
EOT = "\x4"
UP_ARROW = "\e[A"

run_terminal_test("my_gcd(10, 20)",
                  "gcd.multiout",
                  ['\n'])
run_terminal_test("__gcdval__ = my_gcd(10, 20);",
                  "gcdsc.multiout",
                  ['\n'])
@test __gcdval__ == gcd(10, 20)
