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

licenses(["notice"])

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//:__subpackages__"],
)

# Necessary for documentation generation
exports_files(
    glob(["*.bzl"]),
)

bzl_library(
    name = "analysis_test_bzl",
    srcs = ["analysis_test.bzl"],
)

bzl_library(
    name = "matching_bzl",
    srcs = ["matching.bzl"],
)

bzl_library(
    name = "int_subject_bzl",
    srcs = ["int_subject.bzl"],
    deps = [
        ":check_util_bzl",
        ":truth_common_bzl",
        "@bazel_skylib//lib:types",
    ],
)

bzl_library(
    name = "bool_subject_bzl",
    srcs = ["bool_subject.bzl"],
    deps = [
        ":check_util_bzl",
    ],
)

bzl_library(
    name = "collection_subject_bzl",
    srcs = ["collection_subject.bzl"],
    deps = [
        ":check_util_bzl",
        ":failure_messages_bzl",
        ":int_subject_bzl",
        ":matching_bzl",
        ":truth_common_bzl",
        ":util_bzl",
    ],
)

bzl_library(
    name = "label_subject_bzl",
    srcs = ["label_subject.bzl"],
    deps = [
        ":check_util_bzl",
        ":truth_common_bzl",
        "@bazel_skylib//lib:types",
    ],
)

bzl_library(
    name = "ordered_bzl",
    srcs = ["ordered.bzl"],
    deps = [
    ],
)

bzl_library(
    name = "truth_common_bzl",
    srcs = [
        "truth_common.bzl",
    ],
    deps = ["@bazel_skylib//lib:types"],
)

bzl_library(
    name = "check_util_bzl",
    srcs = [
        "check_util.bzl",
    ],
    deps = [
        ":compare_util_bzl",
        ":failure_messages_bzl",
        ":matching_bzl",
        ":ordered_bzl",
        ":truth_common_bzl",
        "@bazel_skylib//lib:types",
    ],
)

bzl_library(
    name = "failure_messages_bzl",
    srcs = ["failure_messages.bzl"],
    deps = [":truth_common_bzl"],
)

bzl_library(
    name = "compare_util_bzl",
    srcs = ["compare_util.bzl"],
    deps = [":truth_common_bzl"],
)

bzl_library(
    name = "expect_meta_bzl",
    srcs = ["expect_meta.bzl"],
    deps = ["//lib:unittest"],
)

bzl_library(
    name = "default_info_subject_bzl",
    srcs = ["default_info_subject.bzl"],
    deps = [
        ":depset_file_subject_bzl",
        ":file_subject_bzl",
        ":runfiles_subject_bzl",
    ],
)

bzl_library(
    name = "depset_file_subject_bzl",
    srcs = ["depset_file_subject.bzl"],
    deps = [
        ":check_util_bzl",
        ":collection_subject_bzl",
        ":failure_messages_bzl",
        ":matching_bzl",
        ":truth_common_bzl",
        "//lib:util_bzl",
    ],
)

bzl_library(
    name = "instrumented_files_info_subject_bzl",
    srcs = ["instrumented_files_info_subject.bzl"],
    deps = [":depset_file_subject_bzl"],
)

bzl_library(
    name = "str_subject_bzl",
    srcs = ["str_subject.bzl"],
    deps = [
        ":check_util_bzl",
        ":collection_subject_bzl",
    ],
)

bzl_library(
    name = "file_subject_bzl",
    srcs = ["file_subject.bzl"],
    deps = [
        ":str_subject_bzl",
    ],
)

bzl_library(
    name = "dict_subject_bzl",
    srcs = ["dict_subject.bzl"],
    deps = [
        ":collection_subject_bzl",
        ":compare_util_bzl",
        ":failure_messages_bzl",
    ],
)

bzl_library(
    name = "action_subject_bzl",
    srcs = ["action_subject.bzl"],
    deps = [
        ":collection_subject_bzl",
        ":depset_file_subject_bzl",
        ":dict_subject_bzl",
        ":failure_messages_bzl",
        ":str_subject_bzl",
        ":truth_common_bzl",
    ],
)

bzl_library(
    name = "execution_info_subject_bzl",
    srcs = ["execution_info_subject.bzl"],
    deps = [
        ":dict_subject_bzl",
        ":str_subject_bzl",
    ],
)

bzl_library(
    name = "run_environment_info_subject_bzl",
    srcs = ["run_environment_info_subject.bzl"],
    deps = [
        ":collection_subject_bzl",
        ":dict_subject_bzl",
    ],
)

bzl_library(
    name = "runfiles_subject_bzl",
    srcs = ["runfiles_subject.bzl"],
    deps = [
        ":check_util_bzl",
        ":collection_subject_bzl",
        ":failure_messages_bzl",
        ":matching_bzl",
        ":truth_common_bzl",
        "//lib:util_bzl",
    ],
)

bzl_library(
    name = "struct_subject_bzl",
    srcs = ["struct_subject.bzl"],
)

bzl_library(
    name = "target_subject_bzl",
    srcs = ["target_subject.bzl"],
    deps = [
        ":action_subject_bzl",
        ":bool_subject_bzl",
        ":collection_subject_bzl",
        ":depset_file_subject_bzl",
        ":execution_info_subject_bzl",
        ":file_subject_bzl",
        ":instrumented_files_info_subject_bzl",
        ":label_subject_bzl",
        ":run_environment_info_subject_bzl",
        ":runfiles_subject_bzl",
        ":truth_common_bzl",
        "//lib:util_bzl",
    ],
)

bzl_library(
    name = "expect_bzl",
    srcs = ["expect.bzl"],
    deps = [
        ":action_subject_bzl",
        ":bool_subject_bzl",
        ":collection_subject_bzl",
        ":depset_file_subject_bzl",
        ":dict_subject_bzl",
        ":expect_meta_bzl",
        ":file_subject_bzl",
        ":int_subject_bzl",
        ":str_subject_bzl",
        ":struct_subject_bzl",
        ":target_subject_bzl",
    ],
)

bzl_library(
    name = "util_bzl",
    srcs = ["util.bzl"],
)
