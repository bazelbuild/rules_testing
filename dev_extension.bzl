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

"""Extension only used for development purposes."""

def _dev_ext_impl(mctx):
    module = mctx.modules[0]
    _dev_toolchains_repo(
        name = "rules_testing_dev_toolchains",
        is_root = module.is_root,
    )

dev = module_extension(
    implementation = _dev_ext_impl,
    tag_classes = {
        "setup": tag_class(),
    },
)

def _dev_toolchains_repo_impl(rctx):
    # If its the root module, then we're in rules_testing and
    # it's a dev dependency situation.
    if rctx.attr.is_root:
        toolchain_build = Label("@python3_11_toolchains//:BUILD.bazel")

        # NOTE: This is brittle. It only works because, luckily,
        # rules_python's toolchain BUILD file is essentially self-contained.
        # It only uses absolute references and doesn't load anything,
        # so we can copy it elsewhere and it still works.
        rctx.symlink(toolchain_build, "BUILD.bazel")
    else:
        rctx.file("BUILD.bazel", "")

_dev_toolchains_repo = repository_rule(
    implementation = _dev_toolchains_repo_impl,
    attrs = {
        "is_root": attr.bool(),
    },
)
