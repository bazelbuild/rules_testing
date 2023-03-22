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

"""StrSubject implementation."""

load(
    ":check_util.bzl",
    "check_not_equals",
    "common_subject_is_in",
)
load(":collection_subject.bzl", "CollectionSubject")

def _str_subject_new(actual, meta):
    """Creates a subject for asserting strings.

    Method: StrSubject.new

    Args:
        actual: ([`str`]) the string to check against.
        meta: ([`ExpectMeta`]) of call chain information.

    Returns:
        [`StrSubject`] object.
    """
    self = struct(actual = actual, meta = meta)
    public = struct(
        # keep sorted start
        contains = lambda *a, **k: _str_subject_contains(self, *a, **k),
        equals = lambda *a, **k: _str_subject_equals(self, *a, **k),
        is_in = lambda *a, **k: common_subject_is_in(self, *a, **k),
        not_equals = lambda *a, **k: _str_subject_not_equals(self, *a, **k),
        split = lambda *a, **k: _str_subject_split(self, *a, **k),
        # keep sorted end
    )
    return public

def _str_subject_contains(self, substr):
    """Assert that the subject contains the substring `substr`.

    Method: StrSubject.contains

    Args:
        self: implicitly added.
        substr: ([`str`]) the substring to check for.
    """
    if substr in self.actual:
        return
    self.meta.add_failure(
        "expected to contain: {}".format(substr),
        "actual: {}".format(self.actual),
    )

def _str_subject_equals(self, other):
    """Assert that the subject string equals the other string.

    Method: StrSubject.equals

    Args:
        self: implicitly added.
        other: ([`str`]) the expected value it should equal.
    """
    if self.actual == other:
        return
    self.meta.add_failure(
        "expected: {}".format(other),
        "actual: {}".format(self.actual),
    )

def _str_subject_not_equals(self, unexpected):
    """Assert that the string is not equal to `unexpected`.

    Method: BoolSubject.not_equals

    Args:
        self: implicitly added.
        unexpected: ([`str`]) the value actual cannot equal.
    """
    return check_not_equals(
        actual = self.actual,
        unexpected = unexpected,
        meta = self.meta,
    )

def _str_subject_split(self, sep):
    """Return a `CollectionSubject` for the actual string split by `sep`.

    Method: StrSubject.split
    """
    return CollectionSubject.new(
        self.actual.split(sep),
        meta = self.meta.derive("split({})".format(repr(sep))),
        container_name = "split string",
        sortable = False,
        element_plural_name = "parts",
    )

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
StrSubject = struct(
    new = _str_subject_new,
)
