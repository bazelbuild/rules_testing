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

"""# TemplateVariableInfoSubject"""

load(":dict_subject.bzl", "DictSubject")

def _template_variable_info_subject_new(info, *, meta):
    """Creates a new `TemplateVariableInfoSubject`

    Method: TemplateVariableInfoSubject.new

    Args:
        info: ([`TemplateVariableInfo`]) provider instance.
        meta: ([`ExpectMeta`]) of call chain information.
    """

    # buildifier: disable=uninitialized
    public = struct(
        variables = lambda *a, **k: _template_variable_info_subject_variables(self, *a, **k),
    )
    self = struct(
        actual = info,
        meta = meta,
    )
    return public

def _template_variable_info_subject_variables(self):
    """Creates a `DictSubject` to assert on the variables dict.

    Method: TemplateVariableInfoSubject.variables

    Args:
        self: implicitly added

    Returns:
        [`DictSubject`] of the str->str variables map.
    """
    return DictSubject.new(
        self.actual.variables,
        meta = self.meta.derive("variables()"),
    )

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
TemplateVariableInfoSubject = struct(
    new = _template_variable_info_subject_new,
    variables = _template_variable_info_subject_variables,
)
