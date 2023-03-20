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

"""# IntSubject"""

load("@bazel_skylib//lib:types.bzl", "types")
load(":check_util.bzl", "check_not_equals", "common_subject_is_in")
load(":truth_common.bzl", "repr_with_type")

def _int_subject_new(value, meta):
    """Create an "IntSubject" struct.

    Method: IntSubject.new

    Args:
        value: (optional [`int`]) the value to perform asserts against may be None.
        meta: ([`ExpectMeta`]) the meta data about the call chain.

    Returns:
        [`IntSubject`].
    """
    if not types.is_int(value) and value != None:
        fail("int required, got: {}".format(repr_with_type(value)))

    # buildifier: disable=uninitialized
    public = struct(
        # keep sorted start
        equals = lambda *a, **k: _int_subject_equals(self, *a, **k),
        is_greater_than = lambda *a, **k: _int_subject_is_greater_than(self, *a, **k),
        is_in = lambda *a, **k: common_subject_is_in(self, *a, **k),
        not_equals = lambda *a, **k: _int_subject_not_equals(self, *a, **k),
        # keep sorted end
    )
    self = struct(actual = value, meta = meta)
    return public

def _int_subject_equals(self, other):
    """Assert that the subject is equal to the given value.

    Method: IntSubject.equals

    Args:
        self: implicitly added.
        other: ([`int`]) value the subject must be equal to.
    """
    if self.actual == other:
        return
    self.meta.add_failure(
        "expected: {}".format(other),
        "actual: {}".format(self.actual),
    )

def _int_subject_is_greater_than(self, other):
    """Asserts that the subject is greater than the given value.

    Method: IntSubject.is_greater_than

    Args:
        self: implicitly added.
        other: ([`int`]) value the subject must be greater than.
    """
    if self.actual != None and other != None and self.actual > other:
        return
    self.meta.add_failure(
        "expected to be greater than: {}".format(other),
        "actual: {}".format(self.actual),
    )

def _int_subject_not_equals(self, unexpected):
    """Assert that the int is not equal to `unexpected`.

    Method: IntSubject.not_equals

    Args:
        self: implicitly added
        unexpected: ([`int`]) the value actual cannot equal.
    """
    return check_not_equals(
        actual = self.actual,
        unexpected = unexpected,
        meta = self.meta,
    )

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
IntSubject = struct(
    new = _int_subject_new,
    equals = _int_subject_equals,
    is_greater_than = _int_subject_is_greater_than,
    not_equals = _int_subject_not_equals,
)
