# Generated documentation for the docs/ directory

load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")
load("@bazel_skylib//rules:build_test.bzl", "build_test")

stardoc(
    name = "truth",
    out = "truth.md",
    input = "//lib:truth.bzl",
    deps = ["//lib:truth_bzl"],
)

stardoc(
    name = "analysis_test",
    out = "analysis_test.md",
    input = "//lib:analysis_test.bzl",
    deps = ["//lib:analysis_test_bzl"],
)

stardoc(
    name = "util",
    out = "util.md",
    input = "//lib:util.bzl",
    deps = ["//lib:util_bzl"],
)

build_test(
    name = "docs_build_test",
    targets = [
        ":truth",
        ":util",
        ":analysis_test",
    ],
)
