"""# Test suite

Aggregates multiple Starlark tests in a single test_suite.
"""

load("//lib:unit_test.bzl", "unit_test")
load("//lib/private:util.bzl", "get_test_name_from_function")

def test_suite(name, *, tests = [], basic_tests = [], test_kwargs = {}):
    """Instantiates given test macros/implementations and gathers their main targets into a `test_suite`.

    Use this function to wrap all tests into a single target.

    ```
    def simple_test_suite(name):
      test_suite(
          name = name,
          tests = [
              your_test,
              your_other_test,
          ]
      )
    ```

    Then, in your `BUILD` file, simply load the macro and invoke it to have all
    of the targets created:

    ```
    load("//path/to/your/package:tests.bzl", "simple_test_suite")
    simple_test_suite(name = "simple_test_suite")
    ```

    Args:
        name: (str) The name of the suite
        tests: (list of callables) Test macros functions that
            define a test. The signature is `def setup(name, **test_kwargs)`,
            where (positional) `name` is name of the test target that must be
            created, and `**test_kwargs` are the additional arguments from the
            test suite's `test_kwargs` arg. The name of the function will
            become the name of the test.
        basic_tests: (list of callables) Test implementation functions
            (functions that implement a test's asserts). Each callable takes a
            single positional arg, `env`, which is information about the test
            environment (see analysis_test docs). The name of the function will
            become the name of the test.
        test_kwargs: (dict) Additional kwargs to pass onto each test (both
            regular and basic test callables).
    """
    test_targets = []

    for setup_func in tests:
        test_name = get_test_name_from_function(setup_func)
        setup_func(name = test_name, **test_kwargs)
        test_targets.append(test_name)

    for impl in basic_tests:
        test_name = get_test_name_from_function(impl)
        unit_test(name = test_name, impl = impl, **test_kwargs)
        test_targets.append(test_name)

    native.test_suite(
        name = name,
        tests = test_targets,
    )
