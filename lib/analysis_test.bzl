# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Analysis testing support."""

load("//lib:truth.bzl", "truth")
load("//lib:util.bzl", "recursive_testing_aspect", "testing_aspect")

def _impl_function_name(impl):
    """Derives the name of the given rule implementation function.

    This can be used for better test feedback.

    Args:
      impl: the rule implementation function

    Returns:
      The name of the given function
    """

    # Starlark currently stringifies a function as "<function NAME>", so we use
    # that knowledge to parse the "NAME" portion out. If this behavior ever
    # changes, we'll need to update this.
    # TODO(bazel-team): Expose a ._name field on functions to avoid this.
    impl_name = str(impl)
    impl_name = impl_name.partition("<function ")[-1]
    impl_name = impl_name.rpartition(">")[0]
    impl_name = impl_name.partition(" ")[0]

    # Strip leading/trailing underscores so that test functions can
    # have private names. This better allows unused tests to be flagged by
    # buildifier (indicating a bug or code to delete)
    return impl_name.strip("_")

def _fail(env, msg):
    """Unconditionally causes the current test to fail.

    Args:
      env: The test environment returned by `unittest.begin`.
      msg: The message to log describing the failure.
    """
    full_msg = "In test %s: %s" % (env.ctx.attr._impl_name, msg)

    # There isn't a better way to output the message in Starlark, so use print.
    # buildifier: disable=print
    print(full_msg)
    env._failures.append(full_msg)

def _begin_analysis_test(ctx):
    """Begins a unit test.

    This should be the first function called in a unit test implementation
    function. It initializes a "test environment" that is used to collect
    assertion failures so that they can be reported and logged at the end of the
    test.

    Args:
      ctx: The Starlark context. Pass the implementation function's `ctx` argument
          in verbatim.

    Returns:
        An analysis_test "environment" struct. The following fields are public:
          * ctx: the underlying rule ctx
          * expect: a truth Expect object (see truth.bzl).
          * fail: A function to register failures for later reporting.

        Other attributes are private, internal details and may change at any time. Do not rely
        on internal details.
    """
    target = getattr(ctx.attr, "target")
    target = target[0] if type(target) == type([]) else target
    failures = []
    failures_env = struct(
        ctx = ctx,
        failures = failures,
    )
    truth_env = struct(
        ctx = ctx,
        fail = lambda msg: _fail(failures_env, msg),
    )
    analysis_test_env = struct(
        ctx = ctx,
        _failures = failures,
        fail = truth_env.fail,
        expect = truth.expect(truth_env),
    )
    return analysis_test_env, target

def _end_analysis_test(env):
    """Ends an analysis test and logs the results.

    This must be called and returned at the end of an analysis test implementation function so
    that the results are reported.

    Args:
      env: The test environment returned by `analysistest.begin`.

    Returns:
      A list of providers needed to automatically register the analysis test result.
    """
    return [AnalysisTestResultInfo(
        success = (len(env._failures) == 0),
        message = "\n".join(env._failures),
    )]

def analysis_test(
        name,
        target,
        impl,
        expect_failure = False,
        attrs = {},
        fragments = [],
        config_settings = {},
        extra_target_under_test_aspects = [],
        collect_actions_recursively = False):
    """Creates an analysis test from its implementation function.

    An analysis test verifies the behavior of a "real" rule target by examining
    and asserting on the providers given by the real target.

    Each analysis test is defined in an implementation function. This function handles
    the boilerplate to create and return a test target and captures the
    implementation function's name so that it can be printed in test feedback.

    An example of an analysis test:

    ```
    def basic_test(name):
        my_rule(name = name + "_subject", ...)

        analysistest(name = name, target = name + "_subject", impl = _your_test)

    def _your_test(env, target, actions):
        env.assert_that(target).runfiles().contains_at_least("foo.txt")
        env.assert_that(find_action(actions, generating="foo.txt")).argv().contains("--a")
    ```

    Args:
      name: Name of the target. It should be a Starlark identifier, matching pattern
          '[A-Za-z_][A-Za-z0-9_]*'.
      target: The target to test.
      impl: The implementation function of the unit test.
      expect_failure: If true, the analysis test will expect the target
          to fail. Assertions can be made on the underlying failure using truth.expect_failure
      attrs: An optional dictionary to supplement the attrs passed to the
          unit test's `rule()` constructor.
      fragments: An optional list of fragment names that can be used to give rules access to
          language-specific parts of configuration.
      config_settings: A dictionary of configuration settings to change for the target under
          test and its dependencies. This may be used to essentially change 'build flags' for
          the target under test, and may thus be utilized to test multiple targets with different
          flags in a single build
      extra_target_under_test_aspects: An optional list of aspects to apply to the target_under_test
          in addition to those set up by default for the test harness itself.
      collect_actions_recursively: If true, runs testing_aspect over all attributes, otherwise
          it is only applied to the target under test.
    Returns:
        (None)
    """

    attrs = dict(attrs)
    attrs["_impl_name"] = attr.string(default = _impl_function_name(impl))

    changed_settings = dict(config_settings)
    if expect_failure:
        changed_settings["//command_line_option:allow_analysis_failures"] = "True"

    target_attr_kwargs = {}
    if changed_settings:
        test_transition = analysis_test_transition(
            settings = changed_settings,
        )
        target_attr_kwargs["cfg"] = test_transition

    attrs["target"] = attr.label(
        aspects = [recursive_testing_aspect if collect_actions_recursively else testing_aspect] + extra_target_under_test_aspects,
        mandatory = True,
        **target_attr_kwargs
    )

    def wrapped_impl(ctx):
        env, target = _begin_analysis_test(ctx)
        impl(env, target)
        return _end_analysis_test(env)

    return testing.analysis_test(
        name,
        wrapped_impl,
        attrs = attrs,
        fragments = fragments,
        attr_values = {"target": target},
    )

def test_suite(name, tests, test_kwargs = {}):
    """Instantiates given test macros and gathers their main targets into a `test_suite`.

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
      name: The name of the `test_suite` target.
      tests: A list of test macros, each taking `name` as a parameter, which
            will be passed the computed name of the test.
      test_kwargs: Additional kwargs to pass onto each test function call.
    """
    test_targets = []
    for call in tests:
        test_name = _impl_function_name(call)
        call(name = test_name, **test_kwargs)
        test_targets.append(test_name)

    native.test_suite(
        name = name,
        tests = test_targets,
    )
