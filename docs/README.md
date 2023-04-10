# rules_testing docs generation

The docs for rules_testing are generated using a combination of Sphinx, Bazel,
and Readthedocs.org. The Markdown files in source control are unlikely to render
properly without the Sphinx processing step because they rely on Sphinx and
MyST-specific Markdown functionalit.

The actual sources that Sphinx consumes are in the docs/source directory.

Manually building the docs isn't necessary -- readthedocs.org will
automatically build and deploy them when commits are pushed to the repo.

## Generating docs for development

To generate docs for development/preview purposes, install
[ibazel](https://github.com/bazelbuild/bazel-watcher)[^ibazel] and run:

```
ibazel run //docs:run_sphinx_build
```

This will build the docs and start a local webserver at http://localhost:8000
where you can view the output. As you edit files, ibazel will detect the file
changes and re-run the build process, and you can simply refresh your browser to
see the changes.

## MyST Markdown flavor

Sphinx is configured to parse Markdown files using MyST, which is a more
advanced flavor of Markdown that supports most features of restructured text and
integrates with Sphinx functionality such as automatic cross references,
creating indexes, and using concise markup to generate rich documentation.

MyST features and behaviors are controlled by the Sphinx configuration file,
`docs/source/conf.py`. For more info, see https://myst-parser.readthedocs.io.

## Sphinx configuration

The Sphinx-specific configuration files and input doc files live in
docs/source -- anything under this directory will be treated by Sphinx as
something it should create documentation for.

The Sphinx configuration is `docs/source/conf.py`. See
https://www.sphinx-doc.org/ for details about the configuration file.

## Readthedocs configuration

There's two basic parts to the readthedocs configuration:

*   `.readthedocs.yaml`: This configuration file controls most settings, such as
    the OS version used to build, Python version, dependencies, what Bazel
    commands to run, etc.
*   https://readthedocs.org/projects/rules-testing: This is the project
    administration page. While most settings come from the config file, this
    controls additional settings such as permissions, what versions are
    published, when to publish changes, etc.

For more readthedocs configuration details, see docs.readthedocs.io.

Of particular note, `//docs:requirements.txt` is used by readthedocs for
specifying Python dependencies (including Sphinx version).

[^ibazel]: Quick install: `npm install -g @bazel/ibazel`
