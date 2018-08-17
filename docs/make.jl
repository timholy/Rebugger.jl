using Documenter, Rebugger

makedocs(
    modules = [Rebugger],
    clean = false,
    format = :html,
    sitename = "Rebugger.jl",
    authors = "Tim Holy",
    linkcheck = !("skiplinks" in ARGS),
    pages = [
        "Home" => "index.md",
        "usage.md",
        "config.md",
        "limitations.md",
        "internals.md",
        "reference.md",
    ],
    # # Use clean URLs, unless built as a "local" build
    # html_prettyurls = !("local" in ARGS),
#    html_canonical = "https://juliadocs.github.io/Rebugger.jl/stable/",
)

deploydocs(
    repo = "github.com/timholy/Rebugger.jl.git",
    target = "build",
    julia = "1.0",
    deps = nothing,
    make = nothing,
)
