# A type for keeping track of the current line number when printing Exprs
struct LineNumberIO <: IO
    io::IO
    linenos::Vector{Int}
    file::Symbol
end

LineNumberIO(io::IO, line, file::Symbol) = LineNumberIO(io, Int[line], file)
LineNumberIO(io::IO, line, file::AbstractString) = LineNumberIO(io, line, Symbol(file))

function Base.show_linenumber(io::LineNumberIO, line, file)
    if file == io.file
        # Count how many newlines we've encountered
        data = io.io.data
        nlines = count(isequal(UInt8('\n')), data) + 1
        lastline = io.linenos[end]
        while nlines > length(io.linenos)
            push!(io.linenos, lastline)
        end
        io.linenos[nlines] = line
    end
    return nothing
end
Base.show_linenumber(io::LineNumberIO, line, ::Nothing) = nothing
Base.show_linenumber(io::LineNumberIO, line) = nothing

Base.write(io::LineNumberIO, x::UInt8) = write(io.io, x)

const linefree = r"\s*(end|else|catch)"
function expression_lines(method::Method)
    def = definition(method)
    lnn = findline(def, identity)
    mfile = lnn === nothing ? method.file : lnn.file
    buf = IOBuffer()
    io = LineNumberIO(buf, method.line, mfile) # deliberately using the in-method numbering
    print(io, def)
    seek(buf, 0)
    methlines = readlines(buf)
    linenos = io.linenos
    lastline = linenos[end]
    while length(linenos) < length(methlines)
        push!(linenos, lastline)
    end
    if startswith(methlines[1], ":(")
        methlines[1] = methlines[1][3:end]
        methlines[end] = methlines[end][1:end-1]
    end
    startswith(methlines[1], "function") && (linenos[1] -= 1)
    # end statements need some correction
    for i = 2:length(methlines)
        if match(linefree, methlines[i]) !== nothing
            linenos[i] = linenos[i-1] + 1
        end
    end
    @assert issorted(linenos)
    keep = Int[]
    for (i, line) in enumerate(methlines)
        if !all(isspace, line)
            push!(keep, i)
        end
    end
    _, line1 = whereis(method)
    return linenos[keep], line1, methlines[keep]
end

function findline(ex, order)
    for a in order(ex.args)
        a isa LineNumberNode && return a
        if a isa Expr
            ln = findline(a, order)
            ln !== nothing && return ln
        end
    end
    return nothing
end

function show_code(term, frame, deflines, nlines)
    width = displaysize(term)[2]
    method = frame.code.scope
    linenos, line1, showlines = deflines   # linenos is in "compiled" numbering, line1 in "current" numbering
    offset = line1 - method.line           # compiled + offset -> current
    nd = ndigits(offset + maximum(linenos))
    line = JuliaInterpreter.linenumber(frame)    # this is in "compiled" numbering
    lineidx = searchsortedfirst(linenos, line)
    idxrange = max(1, lineidx-2):min(length(linenos), lineidx+2)
    iochar = IOBuffer()
    for idx in idxrange
        thisline, codestr = linenos[idx], showlines[idx]
        bchar = breakpoint_style(frame.code, thisline)
        linestr = bchar * lpad(thisline + offset, nd) * "  " * codestr
        linestr = linetrunc(iochar, linestr, width)
        if idx == lineidx
            printstyled(term, linestr, '\n'; bold=true)
        else
            print(term, linestr, '\n')
        end
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
    end
    return String(take!(iochar))
end
linetrunc(linestr, width) = linetrunc(IOBuffer(), linestr, width)

function breakpoint_style(framecode, thisline)
    rng = coderange(framecode, thisline)
    style =' '
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
    depth = length(header.stack) + 1 - header.leveloffset
    frame = header.leveloffset == 0 ? header.frame : header.stack[depth]
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
        for (i, f) in enumerate(header.stack)
            if i == depth
                printstyled(s, indent, f.code.scope, '\n'; color=:light_magenta, bold=true)
            else
                printstyled(s, indent, f.code.scope, '\n'; color=:light_magenta)
            end
            indent *= ' '
        end
        method = frame.code.scope
        printstyled(s, indent, method, '\n'; color=:light_magenta, bold = header.leveloffset==0)
        n = length(frame.code.code.slotnames)
        for i = 1:n
            val = frame.locals[i]
            if val !== nothing
                name = frame.code.code.slotnames[i]
                val = something(val)
                if name == Symbol("#self#") && (isa(val, Type) || sizeof(val) == 0)
                    continue
                end
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
