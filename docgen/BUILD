# Generated documentation for the docs/ directory

load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")
load("@bazel_skylib//rules:build_test.bzl", "build_test")

stardoc(
    name = "truth",
    out = "truth.md",
    input = "//lib:truth.bzl",
    tags = ["skip-bzlmod"],
    deps = ["//lib:truth_bzl"],
)

stardoc(
    name = "analysis_test",
    out = "analysis_test.md",
    input = "//lib:analysis_test.bzl",
    tags = ["skip-bzlmod"],
    deps = ["//lib:analysis_test_bzl"],
)

stardoc(
    name = "util",
    out = "util.md",
    input = "//lib:util.bzl",
    tags = ["skip-bzlmod"],
    deps = ["//lib:util_bzl"],
)

build_test(
    name = "docs_build_test",
    tags = ["skip-bzlmod"],
    targets = [
        ":truth",
        ":util",
        ":analysis_test",
    ],
)
