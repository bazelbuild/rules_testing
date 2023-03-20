# Analysis Tests

Analysis tests are the typical way to test rule behavior. They allow observing
behavior about a rule that isn't visible to a regular test as well as modifying
Bazel configuration state to test rule behavior for e.g. different platforms.

If you've ever wanted to verify...
 * A certain combination of flags
 * Building for another OS
 * That certain providers are returned
 * That aspects behaved a certain way

Or other observable information, then an analysis test does that.

## Quick start

For a quick copy/paste start, create a `.bzl` file with your test code, and a
`BUILD.bazel` file to load your tests and declare them. Here's a skeleton:

```
# BUILD
load(":my_tests.bzl", "my_test_suite")

my_test_suite(name="my_test_suite")
```

```
# my_tests.bzl

load("@rules_testing//lib:analysis_test.bzl", "test_suite", "analysis_test")
load("@rules_testing//lib:util.bzl", "util")

def _test_hello(name):
    util.helper_target(
        native.filegroup,
        name = name + "_subject",
        srcs = ["hello_world.txt"],
    )
    analysis_test(
        name = name,
        impl = _test_hello_impl,
        target = name + "_subject"
    )

def _test_hello_impl(env, target):
    env.expect.that_target(target).default_outputs().contains(
        "hello_world.txt"
    )

def my_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _test_hello,
        ]
    )
```

## Arranging the test

The arrange part of a test defines a target using the rule under test and sets
up its dependencies. This is done by writing a macro, which runs during the
loading phase, that instantiates the target under test and dependencies. All the
targets taking part in the arrangement should be tagged with `manual` so that
they are ignored by common build patterns (e.g. `//...` or `foo:all`).

Example:

```python
load("@rules_proto/defs:proto_library.bzl", "proto_library")


def _test_basic(name):
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
tested (e.g. `_test_frob_compiler_passed_qux_flag`). The setup targets should
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


def _test_basic(name):
  ...

  # (2) Act
  analysis_test(name, target=name + "_foo", impl=_test_basic)
```

<!-- TODO(ilist): Setting configuration flags -->

## Assertions

The assert function (in example `_test_basic`) gets `env` and `target` as
parameters, where...
 * `env` is information about the overall build and test
 * `target` is the target under test (as specified in the `target` attribute
   during the arrange step).

The `env.expect` attribute provides a `truth.Expect` object, which allows
writing fluent asserts:

```python


def _test_basic(env, target):
  env.expect.assert_that(target).runfiles().contains_at_least("foo.txt")
  env.expect.assert_that(target).action_generating("foo.txt").contains_flag_values("--a")

```

Note that you aren't _required_ to use `env.expect`. If you want to perform
asserts another way, then `env.fail()` can be called to register any failures.

<!-- TODO(ilist): ### Assertions on providers -->
<!-- TODO(ilist): ### Assertions on actions -->
<!-- TODO(ilist): ## testing aspects -->


## Collecting the tests together

Use the `test_suite` function to collect all tests together:

```python
load("@rules_testing//lib:analysis_test.bzl", "test_suite")


def proto_library_test_suite(name):
  test_suite(
      name=name,
      tests=[
          _test_basic,
          _test_advanced,
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

### Advanced test collection, reuse, and parameterizing

If you have many tests and rules and need to re-use them between each other,
then there are a couple tricks to make it easy:

* Tests aren't required to all be in the same file. So long as you can load the
  arrange function and pass it to `test_suite`, then you can split tests into
  multiple files for reuse.
* Similarly, arrange functions themselves aren't required to take only a `name`
  argument -- only the functions passed to `test_suite.test` require this.

By using lists and lambdas, we can define collections of tests and have multiple
rules reuse them:

```
# base_tests.bzl

_base_tests = []

def _test_common(name, rule_under_test):
  rule_under_test(...)
  analysis_test(...)

def _test_common_impl(env, target):
  env.expect.that_target(target).contains(...)

_base_tests.append(_test_common)

def create_base_tests(rule_under_test):
    return [
        lambda name: test(name=name, rule_under_test=rule_under_test)
        for test in _base_tests
    ]

# my_binary_tests.bzl
load("//my/my_binary.bzl", "my_binary")
load(":base_tests.bzl", "create_base_tests")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")

def my_binary_suite(name):
    test_suite(
        name = name,
        tests = create_base_tests(my_binary)
    )

# my_test_tests.bzl
load("//my/my_test.bzl", "my_test")
load(":base_tests.bzl", "base_tests")
load("@rules_testing//lib:analysis_test.bzl", "test_suite")

def my_test_suite(name):
    test_suite(
        name = name,
        tests = create_base_tests(my_test)
    )
```

## Tips and best practices

* Use private names for your tests, `def _test_foo`. This allows buildifier to
  detect when you've forgotten to put a test in the `tests` attribute. The
  framework will strip leading underscores from the test name
* Tag the arranged inputs of your tests with `tags=["manual"]`; the
  `util.helper_target` function helps with this. This prevents common build
  patterns (e.g. `bazel test //...` or `bazel test :all`) from trying to
  build them.
* Put each rule's tests into their own directory with their own BUILD
  file. This allows better isolation between the rules' test suites in several ways:
    * When reusing tests, target names are less likely to collide.
    * During the edit-run cycle, modifications to verify one rule that would
      break another rule can be ignored until you're ready to test the other
      rule.
