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

"""# RunfilesSubject"""

load(
    "//lib:util.bzl",
    "is_runfiles",
    "runfiles_paths",
)
load(
    ":check_util.bzl",
    "check_contains_exactly",
    "check_contains_predicate",
    "check_not_contains_predicate",
)
load(":collection_subject.bzl", "CollectionSubject")
load(
    ":failure_messages.bzl",
    "format_actual_collection",
    "format_failure_unexpected_value",
    "format_problem_expected_exactly",
    "format_problem_missing_required_values",
    "format_problem_unexpected_values",
)
load(":matching.bzl", "matching")
load(":truth_common.bzl", "to_list")

def _runfiles_subject_new(runfiles, meta, kind = None):
    """Creates a "RunfilesSubject" struct.

    Method: RunfilesSubject.new

    Args:
        runfiles: ([`runfiles`]) the runfiles to check against.
        meta: ([`ExpectMeta`]) the metadata about the call chain.
        kind: (optional [`str`]) what type of runfiles they are, usually "data"
            or "default". If not known or not applicable, use None.

    Returns:
        [`RunfilesSubject`] object.
    """
    self = struct(
        runfiles = runfiles,
        meta = meta,
        kind = kind,
        actual_paths = sorted(runfiles_paths(meta.ctx.workspace_name, runfiles)),
    )
    public = struct(
        # keep sorted start
        actual = runfiles,
        contains = lambda *a, **k: _runfiles_subject_contains(self, *a, **k),
        contains_at_least = lambda *a, **k: _runfiles_subject_contains_at_least(self, *a, **k),
        contains_exactly = lambda *a, **k: _runfiles_subject_contains_exactly(self, *a, **k),
        contains_none_of = lambda *a, **k: _runfiles_subject_contains_none_of(self, *a, **k),
        contains_predicate = lambda *a, **k: _runfiles_subject_contains_predicate(self, *a, **k),
        not_contains = lambda *a, **k: _runfiles_subject_not_contains(self, *a, **k),
        not_contains_predicate = lambda *a, **k: _runfiles_subject_not_contains_predicate(self, *a, **k),
        # keep sorted end
    )
    return public

def _runfiles_subject_contains(self, expected):
    """Assert that the runfiles contains the provided path.

    Method: RunfilesSubject.contains

    Args:
        self: implicitly added.
        expected: ([`str`]) the path to check is present. This will be formatted
            using `ExpectMeta.format_str` and its current contextual
            keywords. Note that paths are runfiles-root relative (i.e.
            you likely need to include the workspace name.)
    """
    expected = self.meta.format_str(expected)
    matcher = matching.equals_wrapper(expected)
    return _runfiles_subject_contains_predicate(self, matcher)

def _runfiles_subject_contains_at_least(self, paths):
    """Assert that the runfiles contains at least all of the provided paths.

    Method: RunfilesSubject.contains_at_least

    All the paths must exist, but extra paths are allowed. Order is not checked.
    Multiplicity is respected.

    Args:
        self: implicitly added.
        paths: ((collection of [`str`]) | [`runfiles`]) the paths that must
            exist. If a collection of strings is provided, they will be
            formatted using [`ExpectMeta.format_str`], so its template keywords
            can be directly passed. If a `runfiles` object is passed, it is
            converted to a set of path strings.
    """
    if is_runfiles(paths):
        paths = runfiles_paths(self.meta.ctx.workspace_name, paths)

    paths = [self.meta.format_str(p) for p in to_list(paths)]

    # NOTE: We don't return Ordered because there isn't a well-defined order
    # between the different sub-objects within the runfiles.
    CollectionSubject.new(
        self.actual_paths,
        meta = self.meta,
        element_plural_name = "paths",
        container_name = "{}runfiles".format(self.kind + " " if self.kind else ""),
    ).contains_at_least(paths)

def _runfiles_subject_contains_predicate(self, matcher):
    """Asserts that `matcher` matches at least one value.

    Method: RunfilesSubject.contains_predicate

    Args:
        self: implicitly added.
        matcher: callable that takes 1 positional arg ([`str`] path) and returns
            boolean.
    """
    check_contains_predicate(
        self.actual_paths,
        matcher = matcher,
        format_problem = "expected to contain: {}".format(matcher.desc),
        format_actual = lambda: format_actual_collection(
            self.actual_paths,
            name = "{}runfiles".format(self.kind + " " if self.kind else ""),
        ),
        meta = self.meta,
    )

def _runfiles_subject_contains_exactly(self, paths):
    """Asserts that the runfiles contains_exactly the set of paths

    Method: RunfilesSubject.contains_exactly

    Args:
        self: implicitly added.
        paths: ([`collection`] of [`str`]) the paths to check. These will be
            formatted using `meta.format_str`, so its template keywords can
            be directly passed. All the paths must exist in the runfiles exactly
            as provided, and no extra paths may exist.
    """
    paths = [self.meta.format_str(p) for p in to_list(paths)]
    runfiles_name = "{}runfiles".format(self.kind + " " if self.kind else "")

    check_contains_exactly(
        expect_contains = paths,
        actual_container = self.actual_paths,
        format_actual = lambda: format_actual_collection(
            self.actual_paths,
            name = runfiles_name,
        ),
        format_expected = lambda: format_problem_expected_exactly(paths, sort = True),
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

def _runfiles_subject_contains_none_of(self, paths, require_workspace_prefix = True):
    """Asserts the runfiles contain none of `paths`.

    Method: RunfilesSubject.contains_none_of

    Args:
        self: implicitly added.
        paths: ([`collection`] of [`str`]) the paths that should not exist. They should
            be runfiles root-relative paths (not workspace relative). The value
            is formatted using `ExpectMeta.format_str` and the current
            contextual keywords.
        require_workspace_prefix: ([`bool`]) True to check that the path includes the
            workspace prefix. This is to guard against accidentallly passing a
            workspace relative path, which will (almost) never exist, and cause
            the test to always pass. Specify False if the file being checked for
            is _actually_ a runfiles-root relative path that isn't under the
            workspace itself.
    """
    formatted_paths = []
    for path in paths:
        path = self.meta.format_str(path)
        formatted_paths.append(path)
        if require_workspace_prefix:
            _runfiles_subject_check_workspace_prefix(self, path)

    CollectionSubject.new(
        self.actual_paths,
        meta = self.meta,
    ).contains_none_of(formatted_paths)

def _runfiles_subject_not_contains(self, path, require_workspace_prefix = True):
    """Assert that the runfiles does not contain the given path.

    Method: RunfilesSubject.not_contains

    Args:
        self: implicitly added.
        path: ([`str`]) the path that should not exist. It should be a runfiles
            root-relative path (not workspace relative). The value is formatted
            using `format_str`, so its template keywords can be directly
            passed.
        require_workspace_prefix: ([`bool`]) True to check that the path includes the
            workspace prefix. This is to guard against accidentallly passing a
            workspace relative path, which will (almost) never exist, and cause
            the test to always pass. Specify False if the file being checked for
            is _actually_ a runfiles-root relative path that isn't under the
            workspace itself.
    """
    path = self.meta.format_str(path)
    if require_workspace_prefix:
        _runfiles_subject_check_workspace_prefix(self, path)

    if path in self.actual_paths:
        problem, actual = format_failure_unexpected_value(
            container_name = "{}runfiles".format(self.kind + " " if self.kind else ""),
            unexpected = path,
            actual = self.actual_paths,
        )
        self.meta.add_failure(problem, actual)

def _runfiles_subject_not_contains_predicate(self, matcher):
    """Asserts that none of the runfiles match `matcher`.

    Method: RunfilesSubject.not_contains_predicate

    Args:
        self: implicitly added.
        matcher: [`Matcher`] that accepts a string (runfiles root-relative path).
    """
    check_not_contains_predicate(self.actual_paths, matcher, meta = self.meta)

def _runfiles_subject_check_workspace_prefix(self, path):
    if not path.startswith(self.meta.ctx.workspace_name + "/"):
        fail("Rejecting path lacking workspace prefix: this often indicates " +
             "a bug. Include the workspace name as part of the path, or pass " +
             "require_workspace_prefix=False if the path is truly " +
             "runfiles-root relative, not workspace relative.\npath=" + path)

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
RunfilesSubject = struct(
    new = _runfiles_subject_new,
    contains = _runfiles_subject_contains,
    contains_at_least = _runfiles_subject_contains_at_least,
    contains_predicate = _runfiles_subject_contains_predicate,
    contains_exactly = _runfiles_subject_contains_exactly,
    contains_none_of = _runfiles_subject_contains_none_of,
    not_contains = _runfiles_subject_not_contains,
    not_contains_predicate = _runfiles_subject_not_contains_predicate,
    check_workspace_prefix = _runfiles_subject_check_workspace_prefix,
)
