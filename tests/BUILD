load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load(":analysis_test_tests.bzl", "analysis_test_test_suite")
load(":truth_tests.bzl", "truth_test_suite")

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

build_test(
    name = "build_tests",
    targets = [
        "//lib:util_bzl",
    ],
)
