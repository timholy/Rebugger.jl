# This was copied from Debugger.jl and then modified

using TerminalRegressionTests, Rebugger, Revise
using HeaderREPLs, REPL
using Test

function run_terminal_test(cmd, validation, commands)
    dirpath = joinpath(@__DIR__, "ui", "v$(VERSION.major).$(VERSION.minor)")
    isdir(dirpath) || mkpath(dirpath)
    filepath = joinpath(dirpath, validation)
    TerminalRegressionTests.automated_test(filepath, commands) do emuterm
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

Revise.track(Base)  # just to get Info printing out of the way

CTRL_C = "\x3"
EOT = "\x4"
UP_ARROW = "\e[A"

run_terminal_test("gcd(10, 20)",
                  "gcd.multiout",
                  ['\n'])
run_terminal_test("__gcdval__ = gcd(10, 20);",
                  "gcdsc.multiout",
                  ['\n'])
@test __gcdval__ == gcd(10, 20)
