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

"""Utilities for performing comparisons for Truth."""

load(":truth_common.bzl", "to_list")

def _match_result_new(*, found_at, matched_value, matcher):
    """Creates a "MatchResult" struct.

    A `MatchResult` struct is information about how an expected value
    matched to an actual value.

    Args:
        found_at: ([`int`]) the position in the actual container the match
            occurred at.
        matched_value: the actual value that caused the match
        matcher: ([`Matcher`] |  value) the value that matched
    """
    return struct(
        found_at = found_at,
        matched_value = matched_value,
        matcher = matcher,
    )

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
MatchResult = struct(
    new = _match_result_new,
)

def compare_contains_exactly_predicates(*, expect_contains, actual_container):
    """Tells how and if values and predicates correspond 1:1 in the specified order.

    * There must be a 1:1 correspondence between the container values and the
      predicates.
    * Multiplicity is respected (i.e., if the same predicate occurs twice, then
      two distinct elements must match).
    * Matching occurs in first-seen order. That is, a predicate will "consume"
      the first value in `actual_container` it matches.
    * The collection must match all the predicates, no more or less.
    * Checking that the order of matches is the same as the passed-in matchers
      order can be done by call `in_order()`.

    Note that confusing results may occur if predicates with overlapping
    match conditions are used. For example, given:
      actual=["a", "ab", "abc"],
      predicates=[<contains a>, <contains b>, <equals a>]

    Then the result will be they aren't equal: the first two predicates
    consume "a" and "ab", leaving only "abc" for the <equals a> predicate
    to match against, which fails.

    Args:
        expect_contains: ([`collection`] of `Matcher`s) the predicates that must match.
            To perform simple equalty, use `matching.equals_wrapper()`.
        actual_container: ([`collection`]) The container to check within.

    Returns:
        struct with the following attributes:
        * contains_exactly: ([`bool`]) True if all the predicates (and no others)
              matched a distinct element; does not consider order.
        * is_in_order: ([`bool`]) True if the actuals values matched in the same
              order as the expected predicates. False if they were out of order.
              If `contains_exactly=False`, this attribute is undefined.
        * missing: [`list`] of [`Matcher`]s from `expect_contains` that did not find a
              corresponding element in `actual_container`.
        * unexpected: ([`list`]) values from `actual_container` that were not
              present in `expect_contains`.
        * matches: ([`list`] of [`MatchResult`]) information about which elements
              in the two lists that matched each other. If
              `contains_exactly=False`, this attribute is undefined.
    """

    # The basic idea is treating the expected and actual lists as queues of
    # remaining values to search for. This allows the multiplicity of values
    # to be respected and ordering correctness to be computed.
    #
    # Each iteration, we "pop" an element off each queue and...
    #   * If the elements are equal, then all is good: ordering is still
    #     possible, and the required element is present. Start a new iteration.
    #   * Otherwise, we know ordering isn't possible anymore and need to
    #     answer two questions:
    #       1. Is the actual value extra, or elsewhere in the expected values?
    #       2. Is the expected value missing, or elsewhere in the actual values?
    #     If a value exists elsewhere in the other queue, then we have to
    #     remove it to prevent it from being searched for again in a later
    #     iteration.
    # As we go along, we keep track of where expected values matched; this
    # allows for better error reporting.
    expect_contains = to_list(expect_contains)
    actual_container = to_list(actual_container)

    actual_queue = []  # List of (original pos, value)
    for i, value in enumerate(actual_container):
        actual_queue.append([i, value])

    expected_queue = []  # List of (original pos, value)
    matches = []  # List of "MatchResult" structs
    for i, value in enumerate(expect_contains):
        expected_queue.append([i, value])
        matches.append(None)

    missing = []  # List of expected values missing
    unexpected = []  # List of actual values that weren't expected
    ordered = True

    # Start at -1 because the first iteration adds 1
    pos = -1
    loop = range(max(len(actual_queue), len(expected_queue)))
    for _ in loop:
        # Advancing the position is equivalent to removing the queues's head
        pos += 1
        if pos >= len(actual_queue) and pos >= len(expected_queue):
            # Can occur when e.g. actual=[A, B], expected=[B]
            break
        if pos >= len(actual_queue):
            # Fewer actual values than expected, so the rest are missing
            missing.extend([v[1] for v in expected_queue[pos:]])
            break
        if pos >= len(expected_queue):
            # More actual values than expected, so the rest are unexpected
            unexpected.extend([v[1] for v in actual_queue[pos:]])
            break

        actual_entry = actual_queue[pos]
        expected_entry = expected_queue[pos]

        if expected_entry[1].match(actual_entry[1]):
            continue  # Happy path: both are equal and order is maintained.
        ordered = False
        found_at, found_entry = _list_find(
            actual_queue,
            lambda v: expected_entry[1].match(v[1]),
            start = pos,
            end = len(actual_queue),
        )
        if found_at == -1:
            missing.append(expected_entry[1])
        else:
            # Remove it from the queue so a subsequent iteration doesn't
            # try to search for it again.
            actual_queue.pop(found_at)
            matches[expected_entry[0]] = MatchResult.new(
                found_at = found_entry[0],
                matched_value = found_entry[1],
                matcher = expected_entry[1],
            )

        found_at, found_entry = _list_find(
            expected_queue,
            lambda entry: entry[1].match(actual_entry[1]),
            start = pos,
            end = len(expected_queue),
        )
        if found_at == -1:
            unexpected.append(actual_entry[1])
        else:
            # Remove it from the queue so a subsequent iteration doesn't
            # try to search for it again.
            expected_queue.pop(found_at)
            matches[found_entry[0]] = MatchResult.new(
                found_at = actual_entry[0],
                matched_value = actual_entry[1],
                matcher = found_entry[1],
            )

    return struct(
        contains_exactly = not (missing or unexpected),
        is_in_order = ordered,
        missing = missing,
        unexpected = unexpected,
        matches = matches,
    )

def _list_find(search_in, search_for, *, start = 0, end = None):
    """Linear search a list for a value matching a predicate.

    Args:
        search_in: ([`list`]) the list to search within.
        search_for: (callable) accepts 1 positional arg (the current value)
            and returns `bool` (`True` if matched, `False` if not).
        start: ([`int`]) the position within `search_in` to start at. Defaults
            to `0` (start of list)
        end: (optional [`int`]) the position within `search_in` to stop before
            (i.e. the value is exclusive; given a list of length 5, specifying
            `end=5` means it will search the whole list). Defaults to the length
            of `search_in`.
    Returns:
        [`tuple`] of ([`int`] found_at, value).
        * If the value was found, then `found_at` is the offset in `search_in`
          it was found at, and matched value is the element at that offset.
        * If the value was not found, then `found_at=-1`, and the matched
          value is `None`.
    """
    end = len(search_in) if end == None else end
    pos = start
    for _ in search_in:
        if pos >= end:
            return -1, None
        value = search_in[pos]
        if search_for(value):
            return pos, value
        pos += 1
    return -1, None

def compare_dicts(*, expected, actual):
    """Compares two dicts, reporting differences.

    Args:
        expected: ([`dict`]) the desired state of `actual`
        actual: ([`dict`]) the observed dict
    Returns:
        Struct with the following attributes:
        * missing_keys: [`list`] of keys that were missing in `actual`, but present
          in `expected`
        * unexpected_keys: [`list`] of keys that were present in `actual`, but not
          present in `expected`
        * incorrect_entries: ([`dict`] of key -> [`DictEntryMismatch`]) of keys that
          were in both dicts, but whose values were not equal. The value is
          a "DictEntryMismatch" struct, which is defined as a struct with
          attributes:
            * `actual`: the value from `actual[key]`
            * `expected`: the value from `expected[key]`
    """
    all_keys = {key: None for key in actual.keys()}
    all_keys.update({key: None for key in expected.keys()})
    missing_keys = []
    unexpected_keys = []
    incorrect_entries = {}

    for key in sorted(all_keys):
        if key not in actual:
            missing_keys.append(key)
        elif key not in expected:
            unexpected_keys.append(key)
        else:
            actual_value = actual[key]
            expected_value = expected[key]
            if actual_value != expected_value:
                incorrect_entries[key] = struct(
                    actual = actual_value,
                    expected = expected_value,
                )

    return struct(
        missing_keys = missing_keys,
        unexpected_keys = unexpected_keys,
        incorrect_entries = incorrect_entries,
    )
