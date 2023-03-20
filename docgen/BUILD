# Generated documentation for the docs/ directory

load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load(":docgen.bzl", "sphinx_stardoc")

package(
    default_visibility = ["//:__subpackages__"],
)

sphinx_stardoc(
    name = "truth",
    out = "truth.md",
    input = "//lib:truth.bzl",
    tags = ["skip-bzlmod"],
    deps = ["//lib:truth_bzl"],
)

sphinx_stardoc(
    name = "analysis_test",
    out = "analysis_test.md",
    input = "//lib:analysis_test.bzl",
    tags = ["skip-bzlmod"],
    deps = ["//lib:analysis_test_bzl"],
)

sphinx_stardoc(
    name = "util",
    out = "util.md",
    input = "//lib:util.bzl",
    tags = ["skip-bzlmod"],
    deps = ["//lib:util_bzl"],
)

extras = [
    "action_subject",
    "bool_subject",
    "collection_subject",
    "depset_file_subject",
    "dict_subject",
    "execution_info_subject",
    "expect",
    "expect_meta",
    "file_subject",
    "instrumented_files_info_subject",
    "int_subject",
    "label_subject",
    "ordered",
    "run_environment_info_subject",
    "runfiles_subject",
    "str_subject",
    "target_subject",
]

[
    sphinx_stardoc(
        name = name,
        out = name + ".md",
        input = "//lib/private:" + name + ".bzl",
        tags = ["skip-bzlmod"],
        deps = ["//lib/private:" + name + "_bzl"],
    )
    for name in extras
]

##sphinx_stardoc(
##    name = "target_subject",
##    out = "target_subject.md",
##    input = "//lib/private:target_subject.bzl",
##    tags = ["skip-bzlmod"],
##    deps = ["//lib/private:target_subject_bzl"],
##)
##
##sphinx_stardoc(
##    name = "expect_meta",
##    out = "expect_meta.md",
##    input = "//lib/private:expect_meta.bzl",
##    tags = ["skip-bzlmod"],
##    deps = ["//lib/private:expect_meta_bzl"],
##)

filegroup(
    name = "docs",
    srcs = [
        ":analysis_test",
        ":truth",
        ":util",
    ] + extras,
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
