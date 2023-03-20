# TODO(rlevasseur): describe this package.

# sphinx, myst-parser, sphinx-rtd-theme
sh_binary(
    name = "run_sphinx_build",
    srcs = ["run_sphinx_build.sh"],
    args = [
        "$(rootpath :crossrefs.md)",
        "$(rootpaths //docgen:docs)",
    ],
    data = [
        "crossrefs.md",
        ":sphinx_deps",
        "//docgen:docs",
    ],
)

filegroup(
    name = "sphinx_deps",
    srcs = glob(
        [
            "*",
            "source/*",
            "source/_static/**",
            "source/api/index.md",
        ],
        exclude = [
            "source/api/**",
            "build/**",
        ],
    ),
)
