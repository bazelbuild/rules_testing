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

"""LabelSubject"""

load("@bazel_skylib//lib:types.bzl", "types")
load(":check_util.bzl", "common_subject_is_in")
load(":truth_common.bzl", "to_list")

def _label_subject_new(label, meta):
    """Creates a new `LabelSubject` for asserting `Label` objects.

    Method: LabelSubject.new

    Args:
        label: {type}`Label` the label to check against.
        meta: {type}`ExpectMeta` the metadata about the call chain.

    Returns:
        {type}`LabelSubject`.
    """

    # buildifier: disable=uninitialized
    public = struct(
        # keep sorted start
        actual = label,
        equals = lambda *a, **k: _label_subject_equals(self, *a, **k),
        is_in = lambda *a, **k: _label_subject_is_in(self, *a, **k),
        # keep sorted end
    )
    self = struct(actual = label, meta = meta)
    return public

def _label_subject_equals(self, other):
    """Asserts the label is equal to `other`.

    Method: LabelSubject.equals

    Args:
        self: implicitly added.
        other: {type}`Label` | str` the expected value. If a `str` is passed, it
            will be converted to a `Label` using the `Label` function.
    """
    if types.is_string(other):
        other = Label(other)
    if self.actual == other:
        return
    self.meta.add_failure(
        "expected: {}".format(other),
        "actual: {}".format(self.actual),
    )

def _label_subject_is_in(self, any_of):
    """Asserts that the label is any of the provided values.

    Args:
        self: implicitly added.
        any_of: {type}`collection[Label | str]` If strings are
            provided, they must be parsable by `Label`.
    """
    any_of = [
        Label(v) if types.is_string(v) else v
        for v in to_list(any_of)
    ]
    common_subject_is_in(self, any_of)

def _label_subject_typedef():
    """Wrapper for asserts on Label objects

    :::{field} actual
    :type: Label

    The underlying value to assert against.
    :::
    """

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
LabelSubject = struct(
    TYPEDEF = _label_subject_typedef,
    new = _label_subject_new,
    equals = _label_subject_equals,
    is_in = _label_subject_is_in,
)
