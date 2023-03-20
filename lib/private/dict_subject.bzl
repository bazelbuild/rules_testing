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

"""# DictSubject"""

load(":collection_subject.bzl", "CollectionSubject")
load(":compare_util.bzl", "compare_dicts")
load(
    ":failure_messages.bzl",
    "format_dict_as_lines",
    "format_problem_dict_expected",
)

def _dict_subject_new(actual, meta, container_name = "dict", key_plural_name = "keys"):
    """Creates a new `DictSubject`.

    Method: DictSubject.new

    Args:
        actual: ([`dict`]) the dict to assert against.
        meta: ([`ExpectMeta`]) of call chain information.
        container_name: ([`str`]) conceptual name of the dict.
        key_plural_name: ([`str`]) the plural word for the keys of the dict.

    Returns:
        New `DictSubject` struct.
    """

    # buildifier: disable=uninitialized
    public = struct(
        contains_exactly = lambda *a, **k: _dict_subject_contains_exactly(self, *a, **k),
        contains_at_least = lambda *a, **k: _dict_subject_contains_at_least(self, *a, **k),
        contains_none_of = lambda *a, **k: _dict_subject_contains_none_of(self, *a, **k),
        keys = lambda *a, **k: _dict_subject_keys(self, *a, **k),
    )
    self = struct(
        actual = actual,
        meta = meta,
        container_name = container_name,
        key_plural_name = key_plural_name,
    )
    return public

def _dict_subject_contains_at_least(self, at_least):
    """Assert the dict has at least the entries from `at_least`.

    Method: DictSubject.contains_at_least

    Args:
        self: implicitly added.
        at_least: ([`dict`]) the subset of keys/values that must exist. Extra
            keys are allowed. Order is not checked.
    """
    result = compare_dicts(
        expected = at_least,
        actual = self.actual,
    )
    if not result.missing_keys and not result.incorrect_entries:
        return

    self.meta.add_failure(
        problem = format_problem_dict_expected(
            expected = at_least,
            missing_keys = result.missing_keys,
            unexpected_keys = [],
            incorrect_entries = result.incorrect_entries,
            container_name = self.container_name,
            key_plural_name = self.key_plural_name,
        ),
        actual = "actual: {{\n{}\n}}".format(format_dict_as_lines(self.actual)),
    )

def _dict_subject_contains_exactly(self, expected):
    """Assert the dict has exactly the provided values.

    Method: DictSubject.contains_exactly

    Args:
        self: implicitly added
        expected: ([`dict`]) the values that must exist. Missing values or
            extra values are not allowed. Order is not checked.
    """
    result = compare_dicts(
        expected = expected,
        actual = self.actual,
    )

    if (not result.missing_keys and not result.unexpected_keys and
        not result.incorrect_entries):
        return

    self.meta.add_failure(
        problem = format_problem_dict_expected(
            expected = expected,
            missing_keys = result.missing_keys,
            unexpected_keys = result.unexpected_keys,
            incorrect_entries = result.incorrect_entries,
            container_name = self.container_name,
            key_plural_name = self.key_plural_name,
        ),
        actual = "actual: {{\n{}\n}}".format(format_dict_as_lines(self.actual)),
    )

def _dict_subject_contains_none_of(self, none_of):
    """Assert the dict contains none of `none_of` keys/values.

    Method: DictSubject.contains_none_of

    Args:
        self: implicitly added
        none_of: ([`dict`]) the keys/values that must not exist. Order is not
            checked.
    """
    result = compare_dicts(
        expected = none_of,
        actual = self.actual,
    )
    none_of_keys = sorted(none_of.keys())
    if (sorted(result.missing_keys) == none_of_keys or
        sorted(result.incorrect_entries.keys()) == none_of_keys):
        return

    incorrect_entries = {}
    for key, not_expected in none_of.items():
        actual = self.actual[key]
        if actual == not_expected:
            incorrect_entries[key] = struct(
                actual = actual,
                expected = "<not {}>".format(not_expected),
            )

    self.meta.add_failure(
        problem = format_problem_dict_expected(
            expected = none_of,
            missing_keys = [],
            unexpected_keys = [],
            incorrect_entries = incorrect_entries,
            container_name = self.container_name + " to be missing",
            key_plural_name = self.key_plural_name,
        ),
        actual = "actual: {{\n{}\n}}".format(format_dict_as_lines(self.actual)),
    )

def _dict_subject_keys(self):
    """Returns a `CollectionSubject` for the dict's keys.

    Method: DictSubject.keys

    Args:
        self: implicitly added

    Returns:
        [`CollectionSubject`] of the keys.
    """
    return CollectionSubject.new(
        self.actual.keys(),
        meta = self.meta.derive("keys()"),
        container_name = "dict keys",
        element_plural_name = "keys",
    )

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
DictSubject = struct(
    new = _dict_subject_new,
    contains_at_least = _dict_subject_contains_at_least,
    contains_exactly = _dict_subject_contains_exactly,
    contains_none_of = _dict_subject_contains_none_of,
    keys = _dict_subject_keys,
)
