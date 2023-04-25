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

"""# RunEnvironmentInfoSubject"""

load(":collection_subject.bzl", "CollectionSubject")
load(":dict_subject.bzl", "DictSubject")

def _run_environment_info_subject_new(info, *, meta):
    """Creates a new `RunEnvironmentInfoSubject`

    Method: RunEnvironmentInfoSubject.new

    Args:
        info: ([`RunEnvironmentInfo`]) provider instance.
        meta: ([`ExpectMeta`]) of call chain information.
    """

    # buildifier: disable=uninitialized
    public = struct(
        environment = lambda *a, **k: _run_environment_info_subject_environment(self, *a, **k),
        inherited_environment = lambda *a, **k: _run_environment_info_subject_inherited_environment(self, *a, **k),
    )
    self = struct(
        actual = info,
        meta = meta,
    )
    return public

def _run_environment_info_subject_environment(self):
    """Creates a `DictSubject` to assert on the environment dict.

    Method: RunEnvironmentInfoSubject.environment

    Args:
        self: implicitly added

    Returns:
        [`DictSubject`] of the str->str environment map.
    """
    return DictSubject.new(
        self.actual.environment,
        meta = self.meta.derive("environment()"),
    )

def _run_environment_info_subject_inherited_environment(self):
    """Creates a `CollectionSubject` to assert on the inherited_environment list.

    Method: RunEnvironmentInfoSubject.inherited_environment

    Args:
        self: implicitly added

    Returns:
        [`CollectionSubject`] of [`str`]; from the
        [`RunEnvironmentInfo.inherited_environment`] list.
    """
    return CollectionSubject.new(
        self.actual.inherited_environment,
        meta = self.meta.derive("inherited_environment()"),
    )

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
RunEnvironmentInfoSubject = struct(
    new = _run_environment_info_subject_new,
    environment = _run_environment_info_subject_environment,
    inherited_environment = _run_environment_info_subject_inherited_environment,
)
