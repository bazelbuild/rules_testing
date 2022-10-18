# Testing Rule's Implementation

Use this framework to test a rule's implementation function.

Bazel's evaluation is separated into three phases: loading, analysis, and
execution. Bazel evaluates a rule during the analysis phase. For each target
rule's implementation function is evaluated, given providers from all of
target's it directly depends on, toolchains and configuration values. The
implementation may create actions and returns its own set of providers.

With this framework, you can arrange a target and its direct dependencies, using
the rule you would like to test. The framework lets you set custom configuration
values and runs the analysis phase on the target. Within your test function, you
can write asserts on, for example, providers returned by the target under test,
attributes collected by aspects, or other observable information.

## Arranging the test

The arrange part of a test defines a target using the rule under test and sets
up its dependencies. This is done by writing a macro, which runs during the
loading phase, that instantiates the target under test and dependencies. All the
targets taking part in the arrangement should be tagged with `manual` so that
they are ignored by common build patterns (e.g. `//...` or `foo:all`).

Example:

```python
load("@rules_proto/defs:proto_library.bzl", "proto_library")


def test_basic(name):
  """Verifies basic behavior of a proto_library rule."""
  # (1) Arrange
  proto_library(name=name + '_foo', srcs=["foo.proto"], deps=[name + "_bar"], tags=["manual"])
  proto_library(name=name + '_bar', srcs=["bar.proto"], tags=["manual"])

  # (2) Act
  ...
```

TIP: Source source files aren't required to exist. This is because the analysis
phase only records the path to source files; they aren't read until after the
analysis phase. The macro function should be named after the behaviour being
tested (e.g. `test_frob_compiler_passed_qux_flag`). The setup targets should
follow the
[macro naming conventions](https://bazel.build/rules/macros#conventions), that
is all targets should include the name argument as a prefix -- this helps tests
avoid creating conflicting names.

<!-- TODO(ilist): Mocking implicit dependencies -->

### Limitations

Bazel limits the number of transitive dependencies that can be used in the
setup. The limit is controlled by
[`--analysis_testing_deps_limit`](https://bazel.build/reference/command-line-reference#flag--analysis_testing_deps_limit)
flag.

Mocking toolchains (adding a toolchain used only in the test) is not possible at
the moment.

## Running the analysis phase

The act part runs the analysis phase for a specific target and calls a user
supplied function. All of the work is done by Bazel and the framework. Use
`analysis_test` macro to pass in the target to analyse and a function that will
be called with the analysis results:

```python
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")


def test_basic(name):
  ...

  # (2) Act
  analysis_test(name, target=name + "_foo", impl=_test_basic)
```

<!-- TODO(ilist): Setting configuration flags -->

## Assertions

The assert function (in example `_test_basic`) gets `env` and `target` as
parameters.

The environment `env` provides functions to write fluent asserts. `target` is a
map of providers returned by the tested target.

```python


def _test_basic(env, target):
  env.assert_that(target).runfiles().contains_at_least("foo.txt")
  env.assert_that(target).action_generating("foo.txt").contains_flag_values("--a")

```

<!-- TODO(ilist): ### Assertions on providers -->
<!-- TODO(ilist): ### Assertions on actions -->
<!-- TODO(ilist): ## testing aspects -->
## Collecting the tests together

Use `test_suite` function to collect all tests together:

```python
load("@rules_testing//lib:analysis_test.bzl", "test_suite")


def proto_library_test_suite(name):
  test_suite(
      name=name,
      tests=[
          test_basic,
          test_advanced,
      ]
  )
```

In your `BUILD` file instantiate the suite:

```
load("//path/to/your/package:proto_library_tests.bzl", "proto_library_test_suite")
proto_library_test_suite(name = "proto_library_test_suite")
```

The function instantiates all test macros and wraps them into a single target. This removes the need
to load and call each test separately in the `BUILD` file.
