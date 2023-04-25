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

load("@docs-pypi//:requirements.bzl", "requirement")
load("@rules_python//python:pip.bzl", "compile_pip_requirements")
load("@rules_python//python:py_binary.bzl", "py_binary")

package(
    default_applicable_licenses = ["//:package_license"],
)

sh_binary(
    name = "run_sphinx_build",
    srcs = ["run_sphinx_build.sh"],
    args = [
        "$(rootpath :sphinx_build)",
        "$(rootpath :crossrefs.md)",
        "$(rootpaths //docgen:docs)",
    ],
    data = [
        "crossrefs.md",
        ":sphinx_build",
        ":sphinx_sources",
        "//docgen:docs",
    ],
)

py_binary(
    name = "sphinx_build",
    srcs = ["sphinx_build.py"],
    deps = [
        requirement("sphinx"),
        requirement("sphinx_rtd_theme"),
        requirement("myst_parser"),
    ],
)

# Run bazel run //docs:requirements.update
compile_pip_requirements(
    name = "requirements",
    requirements_in = "requirements.in",
    requirements_txt = "requirements.txt",
    # The requirements output differs on Windows, so just restrict it to Linux.
    # The build process is only run on, and only works for, Linux anyways.
    target_compatible_with = ["@platforms//os:linux"],
)

filegroup(
    name = "sphinx_sources",
    srcs = [
        # This isn't generated like the other files under the api directory,
        # but it can't go in the glob because the exclude param will ignore it.
        "source/api/index.md",
    ] + glob(
        [
            "**",
        ],
        exclude = [
            "source/api/**",  # These are all generated files
            "_build/**",
        ],
    ),
)
