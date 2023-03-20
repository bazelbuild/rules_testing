"""Rules to help generating rules_testing docs."""

load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")
load("@bazel_skylib//rules:build_test.bzl", "build_test")

def sphinx_stardoc(**kwargs):
    stardoc(
        func_template = "func_template.vm",
        header_template = "header_template.vm",
        **kwargs
    )
