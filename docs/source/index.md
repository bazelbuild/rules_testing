# Bazel Rules Testing

rules_testing is a collection of utilities, libraries, and frameworks to make
testing Starlark and Bazel rules easy and pleasant.


## Installation

To use rules_testing, you need to modify `WORKSPACE` or `MODULE.bazel`
to depend on rules_testing. We recommend using bzlmod because it's simpler.

For bzlmod, add this to your `MODULE.bazel`:

```
bazel_dep(name = "rules_testing", version = "<VERSION>", dev_dependency=True)
```

See the [GitHub releases
page](https://github.com/bazelbuild/rules_testing/releases) for available
versions.

For `WORKSPACE`, see the [GitHub releases
page](https://github.com/bazelbuild/rules_testing/releases) for the necessary
config to copy and paste.


## Analysis tests

Analysis testing means testing something during the analysis phase of Bazel
execution -- this is when rule logic is run.

See [Analysis tests](/analysis_tests.md) for how to write analysis tests.

## Fluent asserts

Included in rules_testing is a fluent, truth-style asserts library.

See [Truth docs](/truth.md) for how to use it.


```{toctree}
:glob:
:hidden:

self
*
api/index
```
