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

"""Tests for StructSubject"""

load("//lib:test_suite.bzl", "test_suite")
load("//lib:truth.bzl", "subjects")
load("//tests:test_util.bzl", "test_util")

_tests = []

def _struct_subject_test(env):
    fake_meta = test_util.fake_meta(env)
    actual = subjects.struct(
        struct(n = 1, x = "foo"),
        meta = fake_meta,
        attrs = dict(
            n = subjects.int,
            x = subjects.str,
        ),
    )
    actual.n().equals(1)
    test_util.expect_no_failures(env, fake_meta, "struct.n()")

    actual.n().equals(99)
    test_util.expect_failures(
        env,
        fake_meta,
        "struct.n() failure",
        "expected: 99",
    )

    actual.x().equals("foo")
    test_util.expect_no_failures(env, fake_meta, "struct.foo()")

    actual.x().equals("not-foo")
    test_util.expect_failures(env, fake_meta, "struct.foo() failure", "expected: not-foo")

_tests.append(_struct_subject_test)

def struct_subject_test_suite(name):
    test_suite(name = name, basic_tests = _tests)
