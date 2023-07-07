# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Tests for DefaultInfoSubject."""

load("//lib:analysis_test.bzl", "analysis_test")
load("//lib:test_suite.bzl", "test_suite")
load("//lib:truth.bzl", "matching", "subjects")
load("//lib:util.bzl", "util")
load("//tests:test_util.bzl", "test_util")

_tests = []

def _default_info_subject_test(name):
    util.helper_target(
        _simple,
        name = name + "_subject",
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _default_info_subject_test_impl,
    )

def _default_info_subject_test_impl(env, target):
    fake_meta = test_util.fake_meta(env)
    actual = subjects.default_info(
        target[DefaultInfo],
        meta = fake_meta,
    )

    actual.runfiles().contains_predicate(
        matching.str_matches("default_runfile.txt"),
    )
    test_util.expect_no_failures(env, fake_meta, "check default runfiles success")

    actual.runfiles().contains_predicate(
        matching.str_matches("not-present.txt"),
    )
    test_util.expect_failures(
        env,
        fake_meta,
        "check default runfiles failure",
        "not-present.txt",
    )

    actual.data_runfiles().contains_predicate(
        matching.str_matches("data_runfile.txt"),
    )
    test_util.expect_no_failures(env, fake_meta, "check data runfiles success")

    actual.data_runfiles().contains_predicate(
        matching.str_matches("not-present.txt"),
    )
    test_util.expect_failures(
        env,
        fake_meta,
        "check data runfiles failure",
        "not-present.txt",
    )

    actual.default_outputs().contains_predicate(
        matching.file_path_matches("default_output.txt"),
    )
    test_util.expect_no_failures(env, fake_meta, "check executable success")

    actual.default_outputs().contains_predicate(
        matching.file_path_matches("not-present.txt"),
    )
    test_util.expect_failures(
        env,
        fake_meta,
        "check executable failure",
        "not-present.txt",
    )

    actual.executable().path().contains("subject")
    test_util.expect_no_failures(env, fake_meta, "check executable success")

    actual.executable().path().contains("not-present")
    test_util.expect_failures(
        env,
        fake_meta,
        "check executable failure",
        "not-present",
    )
    actual.runfiles_manifest().path().contains("MANIFEST")
    test_util.expect_no_failures(env, fake_meta, "check runfiles_manifest success")

_tests.append(_default_info_subject_test)

def default_info_subject_test_suite(name):
    test_suite(
        name = name,
        tests = _tests,
    )

def _simple_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(executable, "")
    return [DefaultInfo(
        files = depset([ctx.file.default_output]),
        default_runfiles = ctx.runfiles([ctx.file.default_runfile, executable]),
        data_runfiles = ctx.runfiles([ctx.file.data_runfile]),
        executable = executable,
    )]

_simple = rule(
    implementation = _simple_impl,
    attrs = {
        "default_output": attr.label(default = "default_output.txt", allow_single_file = True),
        "default_runfile": attr.label(default = "default_runfile.txt", allow_single_file = True),
        "data_runfile": attr.label(default = "data_runfile.txt", allow_single_file = True),
    },
)
