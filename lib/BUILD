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
load("//lib/private:util.bzl", "do_nothing")

licenses(["notice"])

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//visibility:private"],
)

bzl_library(
    name = "analysis_test_bzl",
    srcs = ["analysis_test.bzl"],
    visibility = ["//visibility:public"],
    deps = [
        ":test_suite_bzl",
        ":truth_bzl",
        "//lib/private:analysis_test_bzl",
        "//lib/private:util_bzl",
    ],
)

bzl_library(
    name = "truth_bzl",
    srcs = ["truth.bzl"],
    visibility = ["//visibility:public"],
    deps = [
        "//lib/private:bool_subject_bzl",
        "//lib/private:collection_subject_bzl",
        "//lib/private:default_info_subject_bzl",
        "//lib/private:depset_file_subject_bzl",
        "//lib/private:expect_bzl",
        "//lib/private:int_subject_bzl",
        "//lib/private:label_subject_bzl",
        "//lib/private:matching_bzl",
        "//lib/private:struct_subject_bzl",
    ],
)

bzl_library(
    name = "util_bzl",
    srcs = ["util.bzl"],
    visibility = ["//visibility:public"],
    deps = [
        "@bazel_skylib//lib:paths",
        "@bazel_skylib//lib:types",
        "@bazel_skylib//lib:unittest",
        "@bazel_skylib//rules:write_file",
    ],
)

bzl_library(
    name = "unit_test_bzl",
    srcs = ["unit_test.bzl"],
    visibility = ["//visibility:public"],
    deps = [
        "//lib/private:analysis_test_bzl",
    ],
)

bzl_library(
    name = "test_suite_bzl",
    srcs = ["test_suite.bzl"],
    visibility = ["//visibility:public"],
    deps = [
        ":unit_test_bzl",
        "//lib/private:util_bzl",
    ],
)

filegroup(
    name = "test_deps",
    testonly = True,
    srcs = [
        "BUILD",
        ":analysis_test_bzl",
        ":truth_bzl",
        ":util_bzl",
    ],
    visibility = [
        "//tools/build_defs/python/tests/base_rules:__pkg__",
    ],
)

exports_files(
    srcs = [
        "analysis_test.bzl",
        "truth.bzl",
        "util.bzl",
    ],
    visibility = [
        "//docgen:__pkg__",
    ],
)

# Unit tests need some target because they're based upon analysis tests.
do_nothing(
    name = "_stub_target_for_unit_tests",
    visibility = ["//visibility:public"],
)
