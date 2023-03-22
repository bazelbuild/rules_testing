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

"""DepsetFileSubject implementation."""

load("//lib:util.bzl", "is_file")
load(
    ":check_util.bzl",
    "check_contains_at_least_predicates",
    "check_contains_exactly",
    "check_contains_predicate",
    "check_not_contains_predicate",
)
load(":collection_subject.bzl", "CollectionSubject")
load(
    ":failure_messages.bzl",
    "format_actual_collection",
    "format_problem_expected_exactly",
    "format_problem_matched_out_of_order",
    "format_problem_missing_any_values",
    "format_problem_missing_required_values",
    "format_problem_predicates_did_not_match",
    "format_problem_unexpected_values",
)
load(":matching.bzl", "matching")
load(":truth_common.bzl", "to_list")

def _depset_file_subject_new(files, meta, container_name = "depset", element_plural_name = "files"):
    """Creates a DepsetFileSubject asserting on `files`.

    Method: DepsetFileSubject.new

    Args:
        files: ([`depset`] of [`File`]) the values to assert on.
        meta: ([`ExpectMeta`]) of call chain information.
        container_name: ([`str`]) conceptual name of the container.
        element_plural_name: ([`str`]) the plural word for the values in the container.

    Returns:
        [`DepsetFileSubject`] object.
    """

    # buildifier: disable=uninitialized
    public = struct(
        # keep sorted start
        contains = lambda *a, **k: _depset_file_subject_contains(self, *a, **k),
        contains_any_in = lambda *a, **k: _depset_file_subject_contains_any_in(self, *a, **k),
        contains_at_least = lambda *a, **k: _depset_file_subject_contains_at_least(self, *a, **k),
        contains_at_least_predicates = lambda *a, **k: _depset_file_subject_contains_at_least_predicates(self, *a, **k),
        contains_exactly = lambda *a, **k: _depset_file_subject_contains_exactly(self, *a, **k),
        contains_predicate = lambda *a, **k: _depset_file_subject_contains_predicate(self, *a, **k),
        not_contains = lambda *a, **k: _depset_file_subject_not_contains(self, *a, **k),
        not_contains_predicate = lambda *a, **k: _depset_file_subject_not_contains_predicate(self, *a, **k),
        # keep sorted end
    )
    self = struct(
        files = to_list(files),
        meta = meta,
        public = public,
        actual_paths = sorted([f.short_path for f in to_list(files)]),
        container_name = container_name,
        element_plural_name = element_plural_name,
    )
    return public

def _depset_file_subject_contains(self, expected):
    """Asserts that the depset of files contains the provided path/file.

    Method: DepsetFileSubject.contains

    Args:
        self: implicitly added
        expected: ([`str`] | [`File`]) If a string path is provided, it is
            compared to the short path of the files and are formatted using
            [`ExpectMeta.format_str`] and its current contextual keywords. Note
            that, when using `File` objects, two files' configurations must be
            the same for them to be considered equal.
    """
    if is_file(expected):
        actual = self.files
    else:
        expected = self.meta.format_str(expected)
        actual = self.actual_paths

    CollectionSubject.new(
        actual,
        meta = self.meta,
        container_name = self.container_name,
        element_plural_name = self.element_plural_name,
    ).contains(expected)

def _depset_file_subject_contains_at_least(self, expected):
    """Asserts that the depset of files contains at least the provided paths.

    Method: DepsetFileSubject.contains_at_least

    Args:
        self: implicitly added
        expected: ([`collection`] of [`str`] | collection of [`File`]) multiplicity
            is respected. If string paths are provided, they are compared to the
            short path of the files and are formatted using
            `ExpectMeta.format_str` and its current contextual keywords. Note
            that, when using `File` objects, two files' configurations must be the
            same for them to be considered equal.
    Returns:
        [`Ordered`] (see `_ordered_incorrectly_new`).
    """
    expected = to_list(expected)
    if len(expected) < 1 or is_file(expected[0]):
        actual = self.files
    else:
        expected = [self.meta.format_str(v) for v in expected]
        actual = self.actual_paths

    return CollectionSubject.new(
        actual,
        meta = self.meta,
        container_name = self.container_name,
        element_plural_name = self.element_plural_name,
    ).contains_at_least(expected)

def _depset_file_subject_contains_any_in(self, expected):
    """Asserts that any of the values in `expected` exist.

    Method: DepsetFileSubject.contains_any_in

    Args:
        self: implicitly added.
        expected: ([`collection`] of [`str`] paths | [`collection`] of [`File`])
            at least one of the values must exist. Note that, when using `File`
            objects, two files' configurations must be the same for them to be
            considered equal. When string paths are provided, they are compared
            to `File.short_path`.
    """
    expected = to_list(expected)
    if len(expected) < 1 or is_file(expected[0]):
        actual = self.files
    else:
        actual = self.actual_paths

    expected_map = {value: None for value in expected}

    check_contains_predicate(
        actual,
        matcher = matching.is_in(expected_map),
        format_problem = lambda: format_problem_missing_any_values(expected),
        format_actual = lambda: format_actual_collection(
            actual,
            container_name = self.container_name,
        ),
        meta = self.meta,
    )

def _depset_file_subject_contains_at_least_predicates(self, matchers):
    """Assert that the depset is a subset of the given predicates.

    Method: DepsetFileSubject.contains_at_least_predicates

    The depset must match all the predicates. It can contain extra elements.
    The multiplicity of matchers is respected. Checking that the relative order
    of matches is the same as the passed-in matchers order can done by calling
    `in_order()`.

    Args:
        self: implicitly added.
        matchers: ([`list`] of [`Matcher`]) (see `matchers` struct) that
            accept [`File`] objects.

    Returns:
        [`Ordered`] (see `_ordered_incorrectly_new`).
    """
    ordered = check_contains_at_least_predicates(
        self.files,
        matchers,
        format_missing = lambda missing: format_problem_predicates_did_not_match(
            missing,
            element_plural_name = self.element_plural_name,
            container_name = self.container_name,
        ),
        format_out_of_order = format_problem_matched_out_of_order,
        format_actual = lambda: format_actual_collection(
            self.files,
            name = self.container_name,
        ),
        meta = self.meta,
    )
    return ordered

def _depset_file_subject_contains_predicate(self, matcher):
    """Asserts that `matcher` matches at least one value.

    Method: DepsetFileSubject.contains_predicate

    Args:
        self: implicitly added.
        matcher: [`Matcher`] (see `matching` struct) that accepts `File` objects.
    """
    check_contains_predicate(
        self.files,
        matcher = matcher,
        format_problem = matcher.desc,
        format_actual = lambda: format_actual_collection(
            self.files,
            name = self.container_name,
        ),
        meta = self.meta,
    )

def _depset_file_subject_contains_exactly(self, paths):
    """Asserts the depset of files contains exactly the given paths.

    Method: DepsetFileSubject.contains_exactly

    Args:
        self: implicitly added.
        paths: ([`collection`] of [`str`]) the paths that must exist. These are
            compared to the `short_path` values of the files in the depset.
            All the paths, and no more, must exist.
    """
    paths = [self.meta.format_str(p) for p in to_list(paths)]
    check_contains_exactly(
        expect_contains = paths,
        actual_container = self.actual_paths,
        format_actual = lambda: format_actual_collection(
            self.actual_paths,
            name = self.container_name,
        ),
        format_expected = lambda: format_problem_expected_exactly(
            paths,
            sort = True,
        ),
        format_missing = lambda missing: format_problem_missing_required_values(
            missing,
            sort = True,
        ),
        format_unexpected = lambda unexpected: format_problem_unexpected_values(
            unexpected,
            sort = True,
        ),
        format_out_of_order = lambda matches: fail("Should not be called"),
        meta = self.meta,
    )

def _depset_file_subject_not_contains(self, short_path):
    """Asserts that `short_path` is not in the depset.

    Method: DepsetFileSubject.not_contains_predicate

    Args:
        self: implicitly added.
        short_path: ([`str`]) the short path that should not be present.
    """
    short_path = self.meta.format_str(short_path)
    matcher = matching.custom(short_path, lambda f: f.short_path == short_path)
    check_not_contains_predicate(self.files, matcher, meta = self.meta)

def _depset_file_subject_not_contains_predicate(self, matcher):
    """Asserts that nothing in the depset matches `matcher`.

    Method: DepsetFileSubject.not_contains_predicate

    Args:
        self: implicitly added.
        matcher: ([`Matcher`]) that must match. It operates on [`File`] objects.
    """
    check_not_contains_predicate(self.files, matcher, meta = self.meta)

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
DepsetFileSubject = struct(
    new = _depset_file_subject_new,
)
