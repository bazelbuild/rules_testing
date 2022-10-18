# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Utility functions to use in analysis tests."""

def find_action(env, artifact):
    """Finds the action generating the artifact.

    Args:
      env: The testing environment
      artifact: a File or a string
    Returns:
      The action"""

    if type(artifact) == type(""):
        basename = env.target.label.package + "/" + artifact.format(
            name = env.target.label.name,
        )
    else:
        basename = artifact.short_path

    for action in env.actions:
        for file in action.actual.outputs.to_list():
            if file.short_path == basename:
                return action
    return None
