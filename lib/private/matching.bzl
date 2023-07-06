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

"""Implementation of matchers."""

def _match_custom(desc, func):
    """Wrap an arbitrary function up as a Matcher.

    Method: Matcher.new

    `Matcher` struct attributes:

    * `desc`: ([`str`]) a human-friendly description
    * `match`: (callable) accepts 1 positional arg (the value to match) and
        returns [`bool`] (`True` if it matched, `False` if not).

    Args:
        desc: ([`str`]) a human-friendly string describing what is matched.
        func: (callable) accepts 1 positional arg (the value to match) and
            returns [`bool`] (`True` if it matched, `False` if not).

    Returns:
        [`Matcher`] (see above).
    """
    return struct(desc = desc, match = func)

def _match_equals_wrapper(value):
    """Match that a value equals `value`, but use `value` as the `desc`.

    This is a helper so that simple equality comparisons can re-use predicate
    based APIs.

    Args:
        value: object, the value that must be equal to.

    Returns:
        [`Matcher`] (see `_match_custom()`), whose description is `value`.
    """
    return _match_custom(value, lambda other: other == value)

def _match_file_basename_contains(substr):
    """Match that a a `File.basename` string contains a substring.

    Args:
        substr: ([`str`]) the substring to match.

    Returns:
        [`Matcher`] (see `_match_custom()`).
    """
    return struct(
        desc = "<basename contains '{}'>".format(substr),
        match = lambda f: substr in f.basename,
    )

def _match_file_path_matches(pattern):
    """Match that a `File.path` string matches a glob-style pattern.

    Args:
        pattern: ([`str`]) the pattern to match. "*" can be used to denote
            "match anything".

    Returns:
        [`Matcher`] (see `_match_custom`).
    """
    parts = pattern.split("*")
    return struct(
        desc = "<path matches '{}'>".format(pattern),
        match = lambda f: _match_parts_in_order(f.path, parts),
    )

def _match_file_basename_equals(value):
    """Match that a `File.basename` string equals `value`.

    Args:
        value: ([`str`]) the basename to match.

    Returns:
        [`Matcher`] instance
    """
    return struct(
        desc = "<file basename equals '{}'>".format(value),
        match = lambda f: f.basename == value,
    )

def _match_file_extension_in(values):
    """Match that a `File.extension` string is any of `values`.

    See also: `file_path_matches` for matching extensions that
    have multiple parts, e.g. `*.tar.gz` or `*.so.*`.

    Args:
        values: ([`list`] of [`str`]) the extensions to match.

    Returns:
        [`Matcher`] instance
    """
    return struct(
        desc = "<file extension is any of {}>".format(repr(values)),
        match = lambda f: f.extension in values,
    )

def _match_is_in(values):
    """Match that the to-be-matched value is in a collection of other values.

    This is equivalent to: `to_be_matched in values`. See `_match_contains`
    for the reversed operation.

    Args:
        values: The collection that the value must be within.

    Returns:
        [`Matcher`] (see `_match_custom()`).
    """
    return struct(
        desc = "<is any of {}>".format(repr(values)),
        match = lambda v: v in values,
    )

def _match_never(desc):
    """A matcher that never matches.

    This is mostly useful for testing, as it allows preventing any match
    while providing a custom description.

    Args:
        desc: ([`str`]) human-friendly string.

    Returns:
        [`Matcher`] (see `_match_custom`).
    """
    return struct(
        desc = desc,
        match = lambda value: False,
    )

def _match_contains(contained):
    """Match that `contained` is within the to-be-matched value.

    This is equivalent to: `contained in to_be_matched`. See `_match_is_in`
    for the reversed operation.

    Args:
        contained: the value that to-be-matched value must contain.

    Returns:
        [`Matcher`] (see `_match_custom`).
    """
    return struct(
        desc = "<contains {}>".format(contained),
        match = lambda value: contained in value,
    )

def _match_str_endswith(suffix):
    """Match that a string contains another string.

    Args:
        suffix: ([`str`]) the suffix that must be present

    Returns:
        [`Matcher`] (see `_match_custom`).
    """
    return struct(
        desc = "<endswith '{}'>".format(suffix),
        match = lambda value: value.endswith(suffix),
    )

def _match_str_matches(pattern):
    """Match that a string matches a glob-style pattern.

    Args:
        pattern: ([`str`]) the pattern to match. `*` can be used to denote
            "match anything". There is an implicit `*` at the start and
            end of the pattern.

    Returns:
        [`Matcher`] object.
    """
    parts = pattern.split("*")
    return struct(
        desc = "<matches '{}'>".format(pattern),
        match = lambda value: _match_parts_in_order(value, parts),
    )

def _match_str_startswith(prefix):
    """Match that a string contains another string.

    Args:
        prefix: ([`str`]) the prefix that must be present

    Returns:
        [`Matcher`] (see `_match_custom`).
    """
    return struct(
        desc = "<startswith '{}'>".format(prefix),
        match = lambda value: value.startswith(prefix),
    )

def _match_parts_in_order(string, parts):
    start = 0
    for part in parts:
        start = string.find(part, start)
        if start == -1:
            return False
    return True

def _is_matcher(obj):
    return hasattr(obj, "desc") and hasattr(obj, "match")

# For the definition of a `Matcher` object, see `_match_custom`.
matching = struct(
    # keep sorted start
    contains = _match_contains,
    custom = _match_custom,
    equals_wrapper = _match_equals_wrapper,
    file_basename_contains = _match_file_basename_contains,
    file_basename_equals = _match_file_basename_equals,
    file_path_matches = _match_file_path_matches,
    file_extension_in = _match_file_extension_in,
    is_in = _match_is_in,
    never = _match_never,
    str_endswith = _match_str_endswith,
    str_matches = _match_str_matches,
    str_startswith = _match_str_startswith,
    is_matcher = _is_matcher,
    # keep sorted end
)
