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

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load(":analysis_test_tests.bzl", "analysis_test_test_suite")
load(":truth_tests.bzl", "truth_test_suite")
load(":unit_test_tests.bzl", "unit_test_test_suite")

licenses(["notice"])

bzl_library(
    name = "analysis_test_tests_bzl",
    srcs = ["analysis_test_tests.bzl"],
    deps = [
        "//lib:analysis_test_bzl",
        "//lib:truth_bzl",
    ],
)

bzl_library(
    name = "truth_tests_bzl",
    srcs = ["truth_tests.bzl"],
    visibility = ["//visibility:private"],
    deps = [
        "//lib:truth_bzl",
        "//lib:util_bzl",
        "@bazel_skylib//lib:unittest",
    ],
)

analysis_test_test_suite(name = "analysis_test_test_suite")

truth_test_suite(name = "truth_tests")

unit_test_test_suite(name = "unit_test_test_suite")

build_test(
    name = "build_tests",
    targets = [
        "//lib:util_bzl",
        "//lib:unit_test_bzl",
        "//lib:analysis_test_bzl",
        "//lib:test_suite_bzl",
        "//lib:truth_bzl",
    ],
)
