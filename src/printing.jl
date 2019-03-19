# A type for keeping track of the current line number when printing Exprs
struct LineNumberIO <: IO
    io::IO
    linenos::Vector{Union{Missing,Int}}
    file::Symbol
end

LineNumberIO(io::IO, line::Integer, file::Symbol) = LineNumberIO(io, Union{Missing,Int}[line], file)
LineNumberIO(io::IO, line::Integer, file::AbstractString) = LineNumberIO(io, line, Symbol(file))

function Base.show_linenumber(io::LineNumberIO, line, file)
    if file == io.file
        # Count how many newlines we've encountered
        data = io.io.data
        nlines = count(isequal(UInt8('\n')), data) + 1
        while nlines > length(io.linenos)
            push!(io.linenos, missing)
        end
        io.linenos[nlines] = line
    end
    return nothing
end
Base.show_linenumber(io::LineNumberIO, line, ::Nothing) = nothing
Base.show_linenumber(io::LineNumberIO, line) = nothing

Base.write(io::LineNumberIO, x::UInt8) = write(io.io, x)

# const linefree = r"\s*(end|else|catch)"
function expression_lines(method::Method)
    def = definition(method)
    if def === nothing
        return [missing], 0, ["<code not available>"]
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
    methlines = readlines(buf)
    linenos = io.linenos
    while length(linenos) < length(methlines)
        push!(linenos, missing)
    end
    if startswith(methlines[1], ":(")
        methlines[1] = methlines[1][3:end]
        methlines[end] = methlines[end][1:end-1]
    end
    startswith(methlines[1], "function") && (linenos[1] -= 1)
    @assert issorted(skipmissing(linenos))
    keeplinenos, keepsrc = Union{Missing,Int}[], String[]
    for (i, line) in enumerate(methlines)
        if !all(isspace, line)
            push!(keepsrc, line)
            ln = linenos[i]
            if ismissing(ln) && i > 1
                # Deliberately go back only one entry
                ln = linenos[i-1]
            end
            push!(keeplinenos, ln)
        end
    end
    # Fill in missing lines where possible
    for i = 2:length(keeplinenos)-1
        if ismissing(keeplinenos[i])
            skip2 = keeplinenos[i-1] + 2 == keeplinenos[i+1]
            if !ismissing(skip2) && skip2
                keeplinenos[i] = keeplinenos[i-1] + 1
            end
        end
    end
    _, line1 = whereis(method)
    return keeplinenos, line1, keepsrc
end

function expression_lines(frame::Frame)
    m = scopeof(frame)
    mlinenos, line1, msrc = expression_lines(m)
    isdefined(m, :generator) || return mlinenos, line1, msrc
    # For a generated function, call the generator to get the expression
    g = m.generator
    gg = g.gen
    vars = JuliaInterpreter.locals(frame)
    ggargs = []
    for v in vars
        v.isparam || continue
        push!(ggargs, v.value)
    end
    for v in vars
        v.isparam && continue
        push!(ggargs, JuliaInterpreter._Typeof(v.value))
    end
    def = gg(ggargs...)
    # Wrap in a function to get indentation
    def = Expr(:function, :(generatedtmp()), def)
    buf = IOBuffer()
    print(buf, def)  # there are no linenos
    seek(buf, 0)
    glines = readlines(buf)
    gsrc = [msrc[1]; glines[2:end]]
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
    line = JuliaInterpreter.linenumber(frame)    # this is in "compiled" numbering
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
        thislinestr = ismissing(thisline) ? " "^nd : lpad(thisline + offset, nd)
        bchar = breakpoint_style(frame.framecode, thisline)
        linestr = bchar * thislinestr * "  " * codestr
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
        for var in JuliaInterpreter.locals(frame)
            name, val = var.name, var.value
            name == Symbol("#self#") && (isa(val, Type) || sizeof(val) == 0) && continue
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
