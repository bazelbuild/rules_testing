# Test suites

The `test_suite` macro is a front-end for easily instantiating groups of
Starlark tests. It can handle both analysis tests and unit tests. Under the
hood, each test is its own target with an aggregating `native.test_suite`
for the group of tests.

## Basic tests

Basic tests are tests that don't require any custom setup or attributes. This is
the common case for tests of utility code that doesn't interact with objects
only available to rules (e.g. Targets). These tests are created using
`unit_test`.

To write such a test, simply write a `unit_test` compatible function (one that
accepts `env`) and pass it to `test_suite.basic_tests`.

```starlark
# BUILD

load(":my_tests.bzl", "my_test_suite")
load("@rules_testing//lib:test_suite.bzl", "test_suite")

my_test_suite(name = "my_tests")

# my_tests.bzl

def _foo_test(env):
  env.expect.that_str(...).equals(...)

def my_test_suite(name):
  test_suite(
    name = name,
    basic_tests = [
      _foo_test,
    ]
  )
```

Note that it isn't _required_ to write a custom test suite function, but doing
so is preferred because it's uncommon for BUILD files to pass around function
objects, and tools won't be confused by it.

## Regular tests

A regular test is a macro that acts as a setup function and is expected to
create a target of the given name (which is added to the underlying test suite).

The setup function can perform arbitrary logic, but in the end, it's expected to
call `unit_test` or `analysis_test` to create a target with the provided name.

If you're writing an `analysis_test`, then you're writing a regular test.

```starlark
# my_tests.bzl
def _foo_test(name):
  analysis_test(
    name = name,
    impl = _foo_test_impl,
    attrs = {"myattr": attr.string(default="default")}
  )

def _foo_test_impl(env):
  env.expect.that_str(...).equals(...)

def my_test_suite(name):
  test_suite(
    name = name,
    tests = [
      _foo_test,
    ]
  )
```

Note that a using a setup function with `unit_test` test is not required to
define custom attributes; the above is just an example. If you want to define
custom attributes for every test in a suite, the `test_kwargs` argument of
`test_suite` can be used to pass additional arguments to all tests in the suite.
