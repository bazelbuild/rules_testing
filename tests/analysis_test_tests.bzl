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

"""Unit tests for analysis_test.bzl."""

load("//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("//lib:truth.bzl", "matching")
load("//lib:util.bzl", "TestingAspectInfo")

###################################
####### change_setting_test #######
###################################

_ChangeSettingInfo = provider(
    doc = "min_os_version for change_setting_test",
    fields = ["min_os_version"],
)

def _change_setting_fake_rule(ctx):
    return [_ChangeSettingInfo(min_os_version = ctx.fragments.cpp.minimum_os_version())]

change_setting_fake_rule = rule(
    implementation = _change_setting_fake_rule,
    fragments = ["cpp"],
)

def test_change_setting(name):
    """Test to verify that an analysis test may change configuration."""
    change_setting_fake_rule(name = name + "_fake_target", tags = ["manual"])

    analysis_test(
        name = name,
        target = name + "_fake_target",
        impl = _test_change_setting,
        config_settings = {
            "//command_line_option:minimum_os_version": "1234.5678",
        },
    )

def _test_change_setting(env, target):
    dep_min_os_version = target[_ChangeSettingInfo].min_os_version
    env.expect.that_str(dep_min_os_version).equals("1234.5678")

####################################
####### failure_testing_test #######
####################################

def _failure_testing_fake_rule(_ctx):
    fail("This rule should never work")

failure_testing_fake_rule = rule(
    implementation = _failure_testing_fake_rule,
)

def test_failure_testing(name):
    """Test to verify that an analysis test may verify a rule fails with fail()."""
    failure_testing_fake_rule(name = name + "_fake_target", tags = ["manual"])

    analysis_test(
        name = name,
        target = name + "_fake_target",
        impl = _test_failure_testing,
        expect_failure = True,
    )

def _test_failure_testing(env, target):
    env.expect.that_target(target).failures().contains_predicate(matching.contains("This rule should never work"))

############################################
####### fail_unexpected_passing_test #######
############################################

def _fail_unexpected_passing_fake_rule(_ctx):
    return []

fail_unexpected_passing_fake_rule = rule(
    implementation = _fail_unexpected_passing_fake_rule,
)

# @unused # TODO(ilist): add a shell test checking it fails
def test_fail_unexpected_passing(name):
    """Test that fails by expecting an error that never occurs."""
    fail_unexpected_passing_fake_rule(name = name + "_fake_target", tags = ["manual"])

    analysis_test(
        name = name,
        target = name + "_fake_target",
        impl = _test_fail_unexpected_passing,
        expect_failure = True,
    )

def _test_fail_unexpected_passing(env, target):
    env.expect.that_target(target).failures().contains_predicate(matching.contains("Oh no, going to fail"))

################################################
####### change_setting_with_failure_test #######
################################################
def _change_setting_with_failure_fake_rule(ctx):
    if ctx.fragments.cpp.minimum_os_version() == "error_error":
        fail("unexpected minimum_os_version!!!")
    return []

change_setting_with_failure_fake_rule = rule(
    implementation = _change_setting_with_failure_fake_rule,
    fragments = ["cpp"],
)

def test_change_setting_with_failure(name):
    change_setting_with_failure_fake_rule(name = name + "_fake_target", tags = ["manual"])

    analysis_test(
        name = name,
        target = name + "_fake_target",
        impl = _test_change_setting_with_failure,
        expect_failure = True,
        config_settings = {
            "//command_line_option:minimum_os_version": "error_error",
        },
    )

def _test_change_setting_with_failure(env, target):
    """Test verifying failure while changing configuration."""
    env.expect.that_target(target).failures().contains_predicate(
        matching.contains("unexpected minimum_os_version!!!"),
    )

####################################
####### inspect_actions_test #######
####################################
def _inspect_actions_fake_rule(ctx):
    out_file = ctx.actions.declare_file("out.txt")
    ctx.actions.run_shell(
        command = "echo 'hello' > %s" % out_file.basename,
        outputs = [out_file],
    )
    return [DefaultInfo(files = depset([out_file]))]

inspect_actions_fake_rule = rule(implementation = _inspect_actions_fake_rule)

def test_inspect_actions(name):
    """Test verifying actions registered by a target."""
    inspect_actions_fake_rule(name = name + "_fake_target", tags = ["manual"])

    analysis_test(name = name, target = name + "_fake_target", impl = _test_inspect_actions)

def _test_inspect_actions(env, target):
    env.expect.that_int(len(target[TestingAspectInfo].actions)).equals(1)
    action_output = target[TestingAspectInfo].actions[0].outputs.to_list()[0]
    env.expect.that_str(action_output.basename).equals("out.txt")

####################################
####### inspect_aspect_test #######
####################################
_AddedByAspectInfo = provider(
    doc = "Example provider added by example aspect",
    fields = {"value": "(str)"},
)

def _example_aspect_impl(_target, _ctx):
    return [_AddedByAspectInfo(value = "attached by aspect")]

example_aspect = aspect(implementation = _example_aspect_impl)

def _inspect_aspect_fake_rule(ctx):
    out_file = ctx.actions.declare_file("out.txt")
    ctx.actions.run_shell(
        command = "echo 'hello' > %s" % out_file.basename,
        outputs = [out_file],
    )
    return [DefaultInfo(files = depset([out_file]))]

inspect_aspect_fake_rule = rule(implementation = _inspect_aspect_fake_rule)

def test_inspect_aspect(name):
    """Test verifying aspect run on a target."""
    inspect_aspect_fake_rule(name = name + "_fake_target", tags = ["manual"])

    analysis_test(
        name = name,
        target = name + "_fake_target",
        impl = _test_inspect_aspect,
        extra_target_under_test_aspects = [example_aspect],
    )

def _test_inspect_aspect(env, target):
    env.expect.that_str(target[_AddedByAspectInfo].value).equals("attached by aspect")

########################################
####### inspect_output_dirs_test #######
########################################
_OutputDirInfo = provider(
    doc = "bin_path for inspect_output_dirs_test",
    fields = ["bin_path"],
)

def _inspect_output_dirs_fake_rule(ctx):
    return [_OutputDirInfo(bin_path = ctx.bin_dir.path)]

inspect_output_dirs_fake_rule = rule(implementation = _inspect_output_dirs_fake_rule)

########################################
####### common_attributes_test #######
########################################

def _test_common_attributes(name):
    native.filegroup(name = name + "_subject")
    _toolchain_template_vars(name = name + "_toolchain_template_vars")
    analysis_test(
        name = name,
        impl = _test_common_attributes_impl,
        target = name + "_subject",
        attr_values = dict(
            features = ["some-feature"],
            tags = ["taga", "tagb"],
            visibility = ["//visibility:private"],
            toolchains = [name + "_toolchain_template_vars"],
            # An empty list means "compatible with everything"
            target_compatible_with = [],
        ),
    )

def _test_common_attributes_impl(env, target):
    _ = target  # @unused
    ctx = env.ctx
    expect = env.expect

    expect.that_collection(ctx.attr.tags).contains_at_least(["taga", "tagb"])

    expect.that_collection(ctx.attr.features).contains_exactly(["some-feature"])

    expect.that_collection(ctx.attr.visibility).contains_exactly([
        Label("//visibility:private"),
    ])

    expect.that_collection(ctx.attr.target_compatible_with).contains_exactly([])

    expanded = ctx.expand_make_variables("cmd", "$(key)", {})
    expect.that_str(expanded).equals("value")

def _toolchain_template_vars_impl(ctx):
    _ = ctx  # @unused
    return [platform_common.TemplateVariableInfo({"key": "value"})]

_toolchain_template_vars = rule(implementation = _toolchain_template_vars_impl)

def analysis_test_test_suite(name):
    test_suite(
        name = name,
        tests = [
            test_change_setting,
            _test_common_attributes,
            test_failure_testing,
            test_change_setting_with_failure,
            test_inspect_actions,
            test_inspect_aspect,
        ],
    )
