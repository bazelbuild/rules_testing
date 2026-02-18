# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""# TemplateVariableInfoSubject

`TemplateVariableInfoSubject` wraps a [`platform_common.TemplateVariableInfo`] object and provides methods for asserting
its state.
"""

load(":dict_subject.bzl", "DictSubject")

def _template_variable_info_subject_new(provider, meta):
    """Creates a subject for asserting platform_common.TemplateVariableInfo providers.

    Method: TemplateVariableInfoSubject.new

    **Public attributes**:
      * `actual`: The wrapped [`platform_common.TemplateVariableInfo`] object.

    Args:
        provider: ([`platform_common.TemplateVariableInfo`]) the provider to check against.
        meta: ([`ExpectMeta`]) metadata about the call chain.

    Returns:
        [`TemplateVariableInfoSubject`] object
    """
    self = struct(provider = provider, meta = meta)
    public = struct(
        # keep sorted start
        actual = provider,
        meta = meta,
        variables = lambda *a, **k: _template_variable_info_subject_variables(self, *a, **k),
        # keep sorted end
    )
    return public

def _template_variable_info_subject_variables(self):
    """Returns a `DictSubject` for the provider's variables.

    Method: TemplateVariableInfoSubject.variables
    """
    return DictSubject.new(
        actual = self.provider.variables,
        meta = self.meta.derive(expr = "variables()"),
    )

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
TemplateVariableInfoSubject = struct(
    new = _template_variable_info_subject_new,
    variables = _template_variable_info_subject_variables,
)
