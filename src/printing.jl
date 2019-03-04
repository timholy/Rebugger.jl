# A type for keeping track of the current line number when printing Exprs
struct LineNumberIO <: IO
    io::IO
    linenos::Vector{Int}
    file::Symbol
end

LineNumberIO(io::IO, file, line) = LineNumberIO(io, Int[line], file)

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

const matches_end = r"\s*end"
function expression_lines(method::Method)
    def = definition(method)
    buf = IOBuffer()
    io = LineNumberIO(buf, method.file, method.line) # deliberately using the in-method numbering
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
        if match(matches_end, methlines[i]) !== nothing
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
        linestr = lpad(thisline + offset, nd) * "  " * codestr
        # Limit it to a single line
        nchars = 0
        for c in linestr
            if nchars == width-2
                print(iochar, '…')
                break
            else
                print(iochar, c)
            end
        end
        linestr = String(take!(iochar))
        if idx == lineidx
            printstyled(term, linestr, '\n'; bold=true)
        else
            print(term, linestr, '\n')
        end
    end
    return length(idxrange)
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
    frame = header.current_frame
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
        method = frame.code.scope
        printstyled(s, method, '\n'; color=:light_magenta)
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
