# A type for keeping track of the current line number when printing Exprs
struct LineNumberIO <: IO
    io::IO
    linenos::Vector{Union{Missing,Int}} # source line number for each printed line of the Expr
    file::Symbol   # used to avoid confusion when we are in expanded macros
end

LineNumberIO(io::IO, line::Integer, file::Symbol) = LineNumberIO(io, Union{Missing,Int}[line], file)
LineNumberIO(io::IO, line::Integer, file::AbstractString) = LineNumberIO(io, line, Symbol(file))

# Instead of printing the source line number to `io.io`, associate it with the
# corresponding line of the printout
function Base.show_linenumber(io::LineNumberIO, line, file)
    if file == io.file
        # Count how many newlines we've encountered
        data = io.io.data
        nlines = count(isequal(UInt8('\n')), data) + 1 # TODO: O(N^2), optimize? See below
        # If there have been more printed lines than assigned line numbers, fill
        # with `missing`
        while nlines > length(io.linenos)
            push!(io.linenos, missing)
        end
        # Record this line number
        io.linenos[nlines] = line
    end
    return nothing
end
Base.show_linenumber(io::LineNumberIO, line, ::Nothing) = nothing
Base.show_linenumber(io::LineNumberIO, line) = nothing

# TODO? intercept `\n` here and break the result up into lines at writing time?
Base.write(io::LineNumberIO, x::UInt8) = write(io.io, x)

# See docstring below
function expression_lines(method::Method)
    def = definition(method)
    if def === nothing
        # If the expression is not available, use the source text. This happens for methods in e.g., boot.jl.
        src, line1 = definition(String, method)
        methstrings = split(chomp(src), '\n')
        return Vector(range(Int(line1), length=length(methstrings))), line1, methstrings
    end
    # We'll use the file in LineNumberNodes to make sure line numbers refer to the "outer"
    # method (and does not get confused by macros etc). Because of symlinks and non-normalized paths,
    # it's more reliable to grab the first LNN for the template filename than to use method.file.
    lnn = findline(def)
    mfile = lnn === nothing ? method.file : lnn.file
    buf = IOBuffer()
    io = LineNumberIO(buf, method.line, mfile) # deliberately using the in-method numbering
    print(io, def)
    seek(buf, 0)
    methstrings = readlines(buf)
    linenos = io.linenos
    while length(linenos) < length(methstrings)
        push!(linenos, missing)
    end
    if startswith(methstrings[1], ":(")
        # Chop off the Expr-quotes from the printing
        methstrings[1] = methstrings[1][3:end]
        methstrings[end] = methstrings[end][1:end-1]
    end
    # If it prints with `function`, adjust numbering for the signature line
    # Note that this works independently of whether it's written as an `=` method
    # in the source code (the contents of that line may not be the same but that's
    # true quite generally)
    startswith(methstrings[1], "function") && (linenos[1] -= 1)
    @assert issorted(skipmissing(linenos))
    # Strip out blank lines from the printed expression
    # These arise from the fact that we intercepted the printing of LineNumberNodes
    keeplinenos, keepstrings = Union{Missing,Int}[], String[]
    for (i, line) in enumerate(methstrings)
        if !all(isspace, line)
            push!(keepstrings, line)
            ln = linenos[i]
            if ismissing(ln) && i > 1
                # Line numbers get associated with the missing LineNumberNodes rather than
                # the succeeding expression line. Thus we look to the previous entry.
                # Deliberately go back only one entry.
                ln = linenos[i-1]
            end
            push!(keeplinenos, ln)
        end
    end
    linenos, methstrings = keeplinenos, keepstrings
    # Fill in missing lines where possible. There is no line info for things like
    # `end`, `catch` and similar; these are subsumed by the block structure.
    # So we try to assign line numbers to these missing elements.
    # However, source text like
    #   for i = 1:5 s += i end
    # and
    #   for i = 1:5 s += i
    #   end
    # and
    #   for i = 1:5
    #       s +=i
    #   end
    # all get printed in the latter format---so the matching will work only under
    # certain conditions.
    lastknown = 1
    for i = 2:length(linenos)-1
        if ismissing(linenos[i])
            if !ismissing(linenos[i+1])
                # Process the previous block of missing statements
                # If the printout has advanced by the same number of lines as the source,
                # we know what the answer must be.
                Δidx = i+1 - lastknown
                Δsrc = linenos[i+1] - linenos[lastknown]
                if Δsrc == Δidx
                    for j = lastknown+1:i
                        linenos[j] = linenos[j-1] + 1
                    end
                end
            end
        else
            lastknown = i
        end
    end
    _, line1 = whereis(method)
    return linenos, line1, keepstrings
end

"""
    linenos, line1, methstrings = expression_lines(frame)

Compute the source lines associated with each printed line of the expression
associated with the method executed in `frame`.
`methstrings` is a vector of strings, one per line of the expression.
`linenos` is a vector in 1-to-1 correspondence with `methstrings`,
 containing either the *compiled* line number or `missing`
if the line number is not available. `line1` contains the *actual* (current) line
number of the first line of the method body.
"""
function expression_lines(frame::Frame)
    m = scopeof(frame)
    mlinenos, line1, msrc = expression_lines(m)
    isdefined(m, :generator) || return mlinenos, line1, msrc
    # The rest of this is specific to generated functions.
    # Call the generator to get the expression. First we have to build up the arguments.
    g = m.generator
    gg = g.gen
    vars = JuliaInterpreter.locals(frame)
    ggargs = []
    # Static parameters come first
    for v in vars
        v.isparam || continue
        push!(ggargs, v.value)
    end
    # Slots are next. Naturally, the generator takes only their types, not their values.
    for v in vars
        v.isparam && continue
        push!(ggargs, JuliaInterpreter._Typeof(v.value))
    end
    # Call the generator
    def = gg(ggargs...)
    # `def` contains just the body. Wrap in a `function` to ensure proper indentation,
    # and then print it.
    def = Expr(:function, :(generatedtmp()), def)
    buf = IOBuffer()
    print(buf, def)  # there are no linenos, so no need for LineNumberIO
    seek(buf, 0)
    glines = readlines(buf)
    # Extract the signature line from `msrc`, and paste the body in
    gsrc = [msrc[1]; glines[2:end]]
    # Assign line numbers. Other than the first line, there *aren't* any, so use `missing`
    linenos = [mlinenos[1]; fill(missing, length(gsrc)-1)]
    return linenos, line1, gsrc
end

function show_code(term, frame, deflines, nlines)
    width = displaysize(term)[2]
    method = scopeof(frame)
    linenos, line1, showlines = deflines   # linenos is in "compiled" numbering, line1 in "current" numbering
    offset = line1 - method.line           # compiled + offset -> current
    known_linenos = skipmissing(linenos)
    nd = isempty(known_linenos) ? 0 : ndigits(offset + maximum(known_linenos))
    line = linenumber_unexpanded(frame)    # this is in "compiled" numbering
    # lineidx = searchsortedfirst(linenos, line)
    # Can't use searchsortedfirst with missing
    lineidx = 0
    for (i, l) in enumerate(linenos)
        if !ismissing(l) && l >= line
            lineidx = i
            break
        end
    end
    idxrange = max(1, lineidx-2):min(length(linenos), lineidx+2)
    iochar = IOBuffer()
    for idx in idxrange
        thisline, codestr = linenos[idx], showlines[idx]
        print(term, breakpoint_style(frame.framecode, thisline))
        if ismissing(thisline)
            print(term, " "^nd)
        else
            linestr = lpad(thisline + offset, nd)
            printstyled(term, linestr; color = thisline==line ? Base.warn_color() : :normal)
        end
        linestr = linetrunc(iochar, codestr, width-nd-3)
        print(term, "  ", linestr, '\n')
    end
    return length(idxrange)
end

# Limit output to a single line
function linetrunc(iochar::IO, linestr, width)
    nchars = 0
    for c in linestr
        if nchars == width-2
            print(iochar, '…')
            break
        else
            print(iochar, c)
        end
        nchars += 1
    end
    return String(take!(iochar))
end
linetrunc(linestr, width) = linetrunc(IOBuffer(), linestr, width)

function breakpoint_style(framecode, thisline)
    rng = coderange(framecode, thisline)
    style = ' '
    breakpoints = framecode.breakpoints
    for i in rng
        if isassigned(breakpoints, i)
            bps = breakpoints[i]
            if !bps.isactive
                if bps.condition === JuliaInterpreter.falsecondition  # removed
                else
                    style = style == ' ' ? 'd' : 'm'   # disabled
                end
            else
                if bps.condition === JuliaInterpreter.truecondition
                    style = style == ' ' ? 'b' : 'm'   # unconditional
                else
                    style = style == ' ' ? 'c' : 'm'   # conditional
                end
            end
        end
    end
    return style
end
breakpoint_style(framecode, ::Missing) = ' '

### Header display

function HeaderREPLs.print_header(io::IO, header::RebugHeader)
    if header.nlines != 0
        HeaderREPLs.clear_header_area(io, header)
    end
    iocount = IOBuffer()  # for counting lines
    for s in (io, iocount)
        if !isempty(header.warnmsg)
            printstyled(s, header.warnmsg, '\n'; color=Base.warn_color())
        end
        if !isempty(header.errmsg)
            printstyled(s, header.errmsg, '\n'; color=Base.error_color())
        end
        if header.current_method != dummymethod
            printstyled(s, header.current_method, '\n'; color=:light_magenta)
        end
        if header.uuid != dummyuuid
            data = stored[header.uuid]
            ds = displaysize(io)
            printer(args...) = printstyled(args..., '\n'; color=:light_blue)
            for (name, val) in zip(data.varnames, data.varvals)
                # Make sure each only spans one line
                if val === nothing
                    val = "nothing"
                end
                try
                    printf_maxsize(printer, s, "  ", name, " = ", val; maxlines=1, maxchars=ds[2]-1)
                catch # don't error just because a print method is borked
                    printstyled(s, "  ", name, " errors in its show method"; color=:red)
                end
            end
        end
    end
    header.nlines = count_display_lines(iocount, displaysize(io))
    header.warnmsg = ""
    header.errmsg = ""
    return nothing
end

function HeaderREPLs.print_header(io::IO, header::InterpretHeader)
    if header.nlines != 0
        HeaderREPLs.clear_header_area(io, header)
    end
    header.frame == nothing && return nothing
    frame, Δ = frameoffset(header.frame, header.leveloffset)
    header.leveloffset -= Δ
    frame === nothing && return nothing
    iocount = IOBuffer()  # for counting lines
    for s in (io, iocount)
        ds = displaysize(io)
        printer(args...) = printstyled(args..., '\n'; color=:light_blue)
        if !isempty(header.warnmsg)
            printstyled(s, header.warnmsg, '\n'; color=Base.warn_color())
        end
        if !isempty(header.errmsg)
            printstyled(s, header.errmsg, '\n'; color=Base.error_color())
        end
        indent = ""
        f = root(frame)
        while f !== nothing
            scope = scopeof(f)
            if f === frame
                printstyled(s, indent, scope, '\n'; color=:light_magenta, bold=true)
            else
                printstyled(s, indent, scope, '\n'; color=:light_magenta)
            end
            indent *= ' '
            f = f.callee
        end
        for (i, var) in enumerate(JuliaInterpreter.locals(frame))
            name, val = var.name, var.value
            name == Symbol("#self#") && (isa(val, Type) || sizeof(val) == 0) && continue
            name == Symbol("") && (name = "@_" * string(i))
            if val === nothing
                val = "nothing"
            end
            try
                printf_maxsize(printer, s, "  ", name, " = ", val; maxlines=1, maxchars=ds[2]-1)
            catch # don't error just because a print method is borked
                printstyled(s, "  ", name, " errors in its show method"; color=:red)
            end
        end
    end
    header.nlines = count_display_lines(iocount, displaysize(io))
    header.warnmsg = ""
    header.errmsg = ""
    return nothing
end

function frameoffset(frame, offset)
    while offset > 0
        cframe = frame.caller
        cframe === nothing && break
        frame = cframe
        offset -= 1
    end
    return frame, offset
end

function linenumber_unexpanded(frame)
    framecode, pc = frame.framecode, frame.pc
    scope = framecode.scope::Method
    codeloc = JuliaInterpreter.codelocation(framecode.src, pc)
    codeloc == 0 && return nothing
    lineinfo = framecode.src.linetable[codeloc]
    while lineinfo.file != scope.file && codeloc > 0
        codeloc -= 1
        lineinfo = framecode.src.linetable[codeloc]
    end
    return JuliaInterpreter.getline(lineinfo)
end
