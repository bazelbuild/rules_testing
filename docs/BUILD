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

load("@rules_python//python:pip.bzl", "compile_pip_requirements")
load("@rules_python//sphinxdocs:readthedocs.bzl", "readthedocs_install")
load("@rules_python//sphinxdocs:sphinx.bzl", "sphinx_build_binary", "sphinx_docs")
load("@rules_python//sphinxdocs:sphinx_stardoc.bzl", "sphinx_stardocs")
load(":bzlmod.bzl", "BZLMOD_ENABLED")

package(
    default_applicable_licenses = ["//:package_license"],
)

# Building docs only works with bzlmod enabled
_TARGET_COMPATIBLE_WITH = (
    ["@platforms//os:linux"] if BZLMOD_ENABLED else ["@platforms//:incompatible"]
)

sphinx_docs(
    name = "docs",
    srcs = glob(
        include = [
            "*.md",
            "**/*.md",
        ],
        exclude = ["README.md"],
    ),
    config = "conf.py",
    formats = ["html"],
    renamed_srcs = {
        "@rules_python//sphinxdocs/inventories:bazel_inventory": "bazel_inventory.inv",
    },
    sphinx = ":sphinx-build",
    strip_prefix = package_name() + "/",
    target_compatible_with = _TARGET_COMPATIBLE_WITH,
    deps = [
        ":bzl_docs",
    ],
)

sphinx_stardocs(
    name = "bzl_docs",
    srcs = [
        "//lib:analysis_test_bzl",
        "//lib:truth_bzl",
        "//lib:util_bzl",
        "//lib/private:action_subject_bzl",
        "//lib/private:bool_subject_bzl",
        "//lib/private:collection_subject_bzl",
        "//lib/private:default_info_subject_bzl",
        "//lib/private:depset_file_subject_bzl",
        "//lib/private:dict_subject_bzl",
        "//lib/private:execution_info_subject_bzl",
        "//lib/private:expect_bzl",
        "//lib/private:expect_meta_bzl",
        "//lib/private:file_subject_bzl",
        "//lib/private:instrumented_files_info_subject_bzl",
        "//lib/private:int_subject_bzl",
        "//lib/private:label_subject_bzl",
        "//lib/private:ordered_bzl",
        "//lib/private:run_environment_info_subject_bzl",
        "//lib/private:runfiles_subject_bzl",
        "//lib/private:str_subject_bzl",
        "//lib/private:struct_subject_bzl",
        "//lib/private:target_subject_bzl",
    ],
    prefix = "api/",
    target_compatible_with = _TARGET_COMPATIBLE_WITH,
)

sphinx_build_binary(
    name = "sphinx-build",
    target_compatible_with = _TARGET_COMPATIBLE_WITH,
    deps = [
        "@docs-pypi//myst_parser",
        "@docs-pypi//readthedocs_sphinx_ext",
        "@docs-pypi//sphinx",
        "@docs-pypi//sphinx_rtd_theme",
        "@docs-pypi//typing_extensions",
        "@rules_python//sphinxdocs/src/sphinx_bzl",
    ],
)

readthedocs_install(
    name = "readthedocs_install",
    docs = [":docs"],
    target_compatible_with = _TARGET_COMPATIBLE_WITH,
)

# Run bazel run //docs:requirements.update
compile_pip_requirements(
    name = "requirements",
    extra_args = ["--upgrade"],
    requirements_in = "requirements.in",
    requirements_txt = "requirements.txt",
    # The requirements output differs on Windows, so just restrict it to Linux.
    # The build process is only run on, and only works for, Linux anyways.
    target_compatible_with = _TARGET_COMPATIBLE_WITH,
)
