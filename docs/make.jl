using Documenter, Rebugger

makedocs(
    modules = [Rebugger],
    clean = false,
    format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
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
)

deploydocs(
    repo = "github.com/timholy/Rebugger.jl.git",
)
