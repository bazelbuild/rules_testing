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

"""Analysis test

Support for testing analysis phase logic, such as rules.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:types.bzl", "types")
load("//lib:truth.bzl", "truth")
load("//lib:util.bzl", "recursive_testing_aspect", "testing_aspect")
load("//lib/private:target_subject.bzl", "PROVIDER_SUBJECT_FACTORIES")
load("//lib/private:util.bzl", "get_test_name_from_function")

_ANALYSIS_TEST_TAGS = [
    "starlark_analysis_test",
    # copybara-marker: skip-coverage-tag
]

_COVERAGE_ENABLED = Label("//lib/private:coverage_enabled")
_INCOMPATIBLE = Label("@platforms//:incompatible")

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
    env.failures.append(full_msg)

def _begin_analysis_test(ctx, provider_subject_factories):
    """Begins a unit test.

    This should be the first function called in a unit test implementation
    function. It initializes a "test environment" that is used to collect
    assertion failures so that they can be reported and logged at the end of the
    test.

    Args:
      ctx: The Starlark context. Pass the implementation function's `ctx` argument
          in verbatim.
      provider_subject_factories: list of ProviderSubjectFactory structs, these are
          additional provider factories on top of built in ones.
          See analysis_test's provider_subject_factory arg for more details on
          the type.

    Returns:
        An analysis_test "environment" struct. The following fields are public:
          * ctx: the underlying rule ctx
          * expect: a truth Expect object (see truth.bzl).
          * fail: A function to register failures for later reporting.

        Other attributes are private, internal details and may change at any time. Do not rely
        on internal details.
    """
    targets = {}
    for attr_name in ctx.attr._target_under_test_attr_names:
        target = getattr(ctx.attr, attr_name)

        # When config settings are changed, singular attr.label attributes are,
        # for some reason, changed to a one-element list instead of just the
        # Target object itself. label_list and label_keyed_string_dict
        # attributes demonstrate this behavior.
        if (types.is_list(target) and
            attr_name not in ctx.attr._target_under_test_list_attr_names):
            target = target[0]
        targets[attr_name] = target

    # When only the target arg is used, pass that directly through.
    # Otherwise, pass a struct of the custom attributes
    if len(targets) == 1 and targets.keys()[0] == "target":
        target_under_test_value = targets.values()[0]
    else:
        target_under_test_value = struct(**targets)

    failures = []
    failures_env = struct(
        ctx = ctx,
        failures = failures,
    )
    truth_env = struct(
        ctx = ctx,
        fail = lambda msg: _fail(failures_env, msg),
        provider_subject_factories = PROVIDER_SUBJECT_FACTORIES + provider_subject_factories,
    )
    analysis_test_env = struct(
        ctx = ctx,
        # Visibility: package; only exposed so that our own tests can verify
        # failure behavior.
        _failures = failures,
        fail = truth_env.fail,
        expect = truth.expect(truth_env),
    )
    return analysis_test_env, target_under_test_value

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
        *,
        name,
        target = None,
        targets = None,
        impl,
        expect_failure = False,
        attrs = {},
        attr_values = {},
        fragments = [],
        config_settings = {},
        extra_target_under_test_aspects = [],
        collect_actions_recursively = False,
        provider_subject_factories = []):
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
      target: The value for the singular target attribute under test.
          Mutually exclusive with the `targets` arg. The type of value passed
          determines the type of attribute created:
            * A list creates an `attr.label_list`
            * A dict creates an `attr.label_keyed_string_dict`
            * Other values (string and Label) create an `attr.label`.
          When set, the `impl` function is passed the value for the attribute
          under test, e.g. passing a list here will pass a list to the `impl`
          function. These targets all have the target under test config applied.
      targets: dict of attribute names and their values to test. Mutually
          exclusive with `target`. Each key must be a valid attribute name and
          Starlark identifier. When set, the `impl` function is passed a struct
          of the targets under test, where each attribute corresponds to this
          dict's keys. The attributes have the target under test config applied
          and can be customized using `attrs`.
      impl: The implementation function of the analysis test.
      expect_failure: If true, the analysis test will expect the target
          to fail. Assertions can be made on the underlying failure using truth.expect_failure
      attrs: An optional dictionary to supplement the attrs passed to the
          unit test's `rule()` constructor. Each value can be one of two types:
          1. An attribute object, e.g. from `attr.string()`.
          2. A dict that describes how to create the attribute; such objects have
             the target under test settings from other args applied. The dict
             supports the following keys:
             * `@attr`: A function to create an attribute, e.g. `attr.label`.
               If unset, `attr.label` is used.
             * `@config_settings`: A dict of config settings; see the
               `config_settings` argument. These are merged with the
               `config_settings` arg, with these having precendence.
             * `aspects`: additional aspects to apply in addition to the
               regular target under test aspects.
             * `cfg`: Not supported; replaced with the target-under-test transition.
             * All other keys are treated as kwargs for the `@attr` function.
      attr_values: An optional dictionary of kwargs to pass onto the
          analysis test target itself (e.g. common attributes like `tags`,
          `target_compatible_with`, or attributes from `attrs`). Note that these
          are for the analysis test target itself, not the target under test.

      fragments: An optional list of fragment names that can be used to give rules access to
          language-specific parts of configuration.
      config_settings: A dictionary of configuration settings to change for the target under
          test and its dependencies. This may be used to essentially change 'build flags' for
          the target under test, and may thus be utilized to test multiple targets with different
          flags in a single build. NOTE: When values that are labels (e.g. for the
          --platforms flag), it's suggested to always explicitly call `Label()`
          on the value before passing it in. This ensures the label is resolved
          in your repository's context, not rule_testing's.
      extra_target_under_test_aspects: An optional list of aspects to apply to the target_under_test
          in addition to those set up by default for the test harness itself.
      collect_actions_recursively: If true, runs testing_aspect over all attributes, otherwise
          it is only applied to the target under test.
      provider_subject_factories: Optional list of ProviderSubjectFactory structs,
          these are additional provider factories on top of built in ones.
          A ProviderSubjectFactory is a struct with the following fields:
          * type: A provider object, e.g. the callable FooInfo object
          * name: A human-friendly name of the provider (eg. "FooInfo")
          * factory: A callable to convert an instance of the provider to a
            subject; see TargetSubject.provider()'s factory arg for the signature.

    Returns:
        (None)
    """
    if target and targets:
        fail("only one of target or targets can be provided")
    elif not target and not targets:
        fail("Exactly one of target and targets must be provided")

    attr_values = dict(attr_values)  # Copy in case its frozen
    attr_values["tags"] = list(attr_values.get("tags") or [])
    attr_values["tags"].extend(_ANALYSIS_TEST_TAGS)

    # The coverage command triggers the execution phase, but analysis tests
    # may not have fully buildable dependencies.
    attr_values["target_compatible_with"] = select({
        _COVERAGE_ENABLED: [_INCOMPATIBLE],
        "//conditions:default": attr_values.get("target_compatible_with") or [],
    })

    if target:
        targets = {"target": target}
        target = None  # Prevent later misuse

    attrs = dict(attrs)  # Copy in case its frozen
    attrs["_impl_name"] = attr.string(default = get_test_name_from_function(impl))

    changed_settings = dict(config_settings)  # Copy in case its frozen
    if expect_failure:
        changed_settings["//command_line_option:allow_analysis_failures"] = "True"

    if changed_settings:
        target_under_test_cfg = analysis_test_transition(
            settings = changed_settings,
        )
    else:
        target_under_test_cfg = None

    applied_aspects = []
    if collect_actions_recursively:
        applied_aspects.append(recursive_testing_aspect)
    else:
        applied_aspects.append(testing_aspect)
    applied_aspects.extend(extra_target_under_test_aspects)

    target_under_test_attr_names = []
    target_under_test_list_attr_names = []

    for attr_name, target in targets.items():
        attr_values[attr_name] = target
        target_under_test_attr_names.append(attr_name)
        if types.is_list(target):
            target_under_test_list_attr_names.append(attr_name)

        if attr_name in attrs:
            continue
        elif types.is_list(target):
            attrs[attr_name] = {"@attr": attr.label_list}
        elif types.is_dict(target):
            attrs[attr_name] = {"@attr": attr.label_keyed_string_dict}
        else:
            attrs[attr_name] = {"@attr": attr.label}

    for attr_name, attr_value in attrs.items():
        if not types.is_dict(attr_value):
            # Leave attribute objects as they are
            continue

        attr_kwargs = dict(attr_value)  # Copy in case its frozen
        attr_func = attr_kwargs.pop("@attr", attr.label)
        attr_config_settings = attr_kwargs.pop("@config_settings", {})

        attr_kwargs.setdefault("mandatory", True)

        # Copy in case its frozen
        attr_kwargs["aspects"] = applied_aspects + attr_kwargs.get("aspects", [])

        if attr_config_settings:
            attr_kwargs["cfg"] = analysis_test_transition(
                settings = dicts.add(changed_settings, attr_config_settings),
            )
        elif target_under_test_cfg:
            attr_kwargs["cfg"] = target_under_test_cfg

        attrs[attr_name] = attr_func(**attr_kwargs)

    if not target_under_test_attr_names:
        fail("At least one target under test must be provided. Specify one " +
             "using the `target` arg or `targets` args")

    attrs["_target_under_test_attr_names"] = attr.string_list(
        default = target_under_test_attr_names,
    )
    attrs["_target_under_test_list_attr_names"] = attr.string_list(
        default = target_under_test_list_attr_names,
    )

    def wrapped_impl(ctx):
        env, target = _begin_analysis_test(ctx, provider_subject_factories)
        impl(env, target)
        return _end_analysis_test(env)

    return testing.analysis_test(
        name,
        wrapped_impl,
        attrs = attrs,
        fragments = fragments,
        attr_values = attr_values,
    )
