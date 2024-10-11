# Unit tests

Unit tests are for Starlark code that isn't specific to analysis-phase or
loading phase cases; usually utility code of some sort. Such tests typically
don't require a rule `ctx` or instantiating other targets to verify the code
under test.

To write such a test, simply write a function accepting `env` and pass it to
`test_suite`. The test suite will pass your verification function to
`unit_test()` for you.

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

## Customizing setup

If you want to customize the setup (loading phase) of a unit test, e.g. to add
custom attributes, then you need to write in the same style as an analysis test:
one function is a verification function, and another function performs setup and
calls `unit_test()`, passing in the verification function.

Custom tests are like basic tests, except you can hook into the loading phase
before the actual unit test is defined. Because you control the invocation of
`unit_test`, you can e.g. define custom attributes specific to the test.

```starlark
# my_tests.bzl
def _foo_test(name):
  unit_test(
    name = name,
    impl = _foo_test_impl,
    attrs = {"myattr": attr.string(default="default")}
  )

def _foo_test_impl(env):
  env.expect.that_str(...).equals(...)

def my_test_suite(name):
  test_suite(
    name = name,
    custom_tests = [
      _foo_test,
    ]
  )
```

Note that a custom test is not required to define custom attributes; the above
is just an example. If you want to define custom attributes for every test in a
suite, the `test_kwargs` argument of `test_suite` can be used to pass additional
arguments to all tests in the suite.
