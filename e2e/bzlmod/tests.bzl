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

"""Tests for basic bzlmod functionality."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")

def _simple_test(name):
    util.helper_target(
        native.filegroup,
        name = name + "_subject",
        srcs = ["src.txt"],
        data = ["data.txt"],
    )
    analysis_test(
        name = name,
        impl = _simple_test_impl,
        target = name + "_subject",
    )

def _simple_test_impl(env, target):
    subject = env.expect.that_target(target)
    subject.default_outputs().contains_exactly(["src.txt"])
    subject.runfiles().contains_exactly(["{workspace}/data.txt"])

def bzlmod_test_suite(name):
    test_suite(name = name, tests = [
        _simple_test,
    ])
