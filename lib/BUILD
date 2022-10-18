load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

licenses(["notice"])

package(
    default_visibility = ["//visibility:public"],
)

bzl_library(
    name = "analysis_test_bzl",
    srcs = ["analysis_test.bzl"],
    deps = [
        "//lib:truth_bzl",
    ],
)

bzl_library(
    name = "truth_bzl",
    srcs = ["truth.bzl"],
    visibility = [
        "//:__subpackages__",
        "//tools/build_defs/python/tests/base_rules:__subpackages__",
    ],
    deps = [
        "//lib:util_bzl",
        "@bazel_skylib//lib:types",
        "@bazel_skylib//lib:unittest",
    ],
)

bzl_library(
    name = "util_bzl",
    srcs = ["util.bzl"],
    visibility = [
        "//devtools/python/blaze:__subpackages__",
        "//:__subpackages__",
        "//tools/build_defs/python/tests:__subpackages__",
    ],
    deps = [
        "@bazel_skylib//lib:paths",
        "@bazel_skylib//lib:types",
        "@bazel_skylib//lib:unittest",
        "@bazel_skylib//rules:write_file",
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
