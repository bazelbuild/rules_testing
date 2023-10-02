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

"""Rules to help generate rules_testing docs."""

load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")

def sphinx_stardocs(name, bzl_libraries, **kwargs):
    """Generate Sphinx-friendly markdown docs using Stardoc for bzl libraries.

    Args:
        name: str, the name of the resulting file group with the generated docs.
        bzl_libraries: list of targets, the libraries to generate docs for.
            The must be in "//foo:{name}_bzl" format; the `{name}` portion
            will become the output file name.
        **kwargs: Additional kwargs to pass onto generated targets (e.g.
            tags)
    """

    docs = []
    for label in bzl_libraries:
        lib_name = Label(label).name.replace("_bzl", "")

        doc_rule_name = "_{}_{}".format(name, lib_name)
        sphinx_stardoc(
            name = "_{}_{}".format(name, lib_name),
            out = lib_name + ".md",
            input = label.replace("_bzl", ".bzl"),
            deps = [label],
            **kwargs
        )
        docs.append(doc_rule_name)

    native.filegroup(
        name = name,
        srcs = docs,
        **kwargs
    )
    build_test(
        name = name + "_build_test",
        targets = docs,
        **kwargs
    )

def sphinx_stardoc(**kwargs):
    stardoc(
        # copybara-marker: stardoc format
        func_template = "func_template.vm",
        header_template = "header_template.vm",
        rule_template = "rule_template.vm",
        provider_template = "provider_template.vm",
        **kwargs
    )
