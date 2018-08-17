# Rebugger

[![Build Status](https://travis-ci.org/timholy/Rebugger.jl.svg?branch=master)](https://travis-ci.org/timholy/Rebugger.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/e9t1wlyy995whchc?svg=true)](https://ci.appveyor.com/project/timholy/Rebugger-jl/branch/master)
[![codecov.io](http://codecov.io/github/timholy/Rebugger.jl/coverage.svg?branch=master)](http://codecov.io/github/timholy/Rebugger.jl?branch=master)

Rebugger is an expression-level debugger for Julia.
It has no ability to interact with or manipulate call stacks (see [ASTInterpreter2](https://github.com/Keno/ASTInterpreter2.jl)),
but it can trace execution via the manipulation of Julia expressions.

The name "Rebugger" has 3 meanings:

- it is a REPL-based debugger (more on that in the documentation)
- it is the [Revise](https://github.com/timholy/Revise.jl)-based debugger
- it supports repeated-execution debugging

## Installation and usage

See the documentation:

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://timholy.github.io/Rebugger.jl/stable)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://timholy.github.io/Rebugger.jl/latest)

Note that Rebugger **requires additional configuration**.

In terms of usage, very briefly

- "step in" is achieved by positioning your cursor in your input line to the beginning of
  the call expression you wish to descend into. Then hit Alt-Shift-Enter.
- for an expression that generates an error, hit "F5" to capture the stacktrace and
  populate your REPL history with a sequence of expressions that contain the method bodies
  of the calls in the stacktrace.

Complete examples are provided in the documentation.

## Status

Rebugger is in early stages of development, and users should currently expect bugs (please do [report](https://github.com/timholy/Rebugger.jl/issues) them).
Neverthess it may be of net benefit for some users.
