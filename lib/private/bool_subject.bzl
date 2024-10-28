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

"""BoolSubject"""

load(":check_util.bzl", "check_not_equals", "common_subject_is_in")

def _bool_subject_new(value, meta):
    """Creates a "BoolSubject" struct.

    Method: BoolSubject.new

    Args:
        value: {type}`bool` the value to assert against.
        meta: {type}`ExpectMeta` the metadata about the call chain.

    Returns:
        {type}`BoolSubject`
    """
    self = struct(actual = value, meta = meta)
    public = struct(
        # keep sorted start
        actual = value,
        equals = lambda *a, **k: _bool_subject_equals(self, *a, **k),
        is_in = lambda *a, **k: common_subject_is_in(self, *a, **k),
        not_equals = lambda *a, **k: _bool_subject_not_equals(self, *a, **k),
        # keep sorted end
    )
    return public

def _bool_subject_equals(self, expected):
    """Assert that the bool is equal to `expected`.

    Method: BoolSubject.equals

    Args:
        self: implicitly added.
        expected: {type}`bool` the expected value.
    """
    if self.actual == expected:
        return
    self.meta.add_failure(
        "expected: {}".format(expected),
        "actual: {}".format(self.actual),
    )

def _bool_subject_not_equals(self, unexpected):
    """Assert that the bool is not equal to `unexpected`.

    Method: BoolSubject.not_equals

    Args:
        self: implicitly added.
        unexpected: {type}`bool` the value actual cannot equal.
    """
    return check_not_equals(
        actual = self.actual,
        unexpected = unexpected,
        meta = self.meta,
    )

def _bool_typedef():
    """A wrapper around {obj}`bool` objects for testing.

    These can be created using {obj}`subjects.bool` or
    {obj}`Expect.that_bool()`.

    :::{field} actual
    :type: bool | None

    The underlying value that is asserted against.
    :::
    """

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
BoolSubject = struct(
    TYPEDEF = _bool_typedef,
    new = _bool_subject_new,
    equals = _bool_subject_equals,
    not_equals = _bool_subject_not_equals,
)
