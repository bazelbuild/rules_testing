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

# Generated documentation for the docs/ directory

load(":docgen.bzl", "sphinx_stardocs")

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//:__subpackages__"],
)

sphinx_stardocs(
    name = "docs",
    bzl_libraries = [
        "//lib:analysis_test_bzl",
        "//lib:truth_bzl",
        "//lib:util_bzl",
        "//lib/private:action_subject_bzl",
        "//lib/private:bool_subject_bzl",
        "//lib/private:collection_subject_bzl",
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
    tags = ["docs"],
)
