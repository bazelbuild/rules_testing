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

"""Functions to aid formatting Truth failure messages."""

load(
    ":truth_common.bzl",
    "enumerate_list_as_lines",
    "guess_format_value",
    "maybe_sorted",
)

def format_actual_collection(actual, name = "values", sort = True):
    """Creates an error message for the observed values of a collection.

    Args:
        actual: ([`collection`]) the values to show
        name: ([`str`]) the conceptual name of the collection.
        sort: ([`bool`]) If true, the collection will be sorted for display.
    Returns:
        ([`str`]) the formatted error message.
    """
    actual = maybe_sorted(actual, sort)
    return "actual {name}:\n{actual}".format(
        name = name,
        actual = enumerate_list_as_lines(actual, prefix = "  "),
    )

def format_failure_missing_all_values(
        element_plural_name,
        container_name,
        *,
        missing,
        actual,
        sort = True):
    """Create error messages when a container is missing all the expected values.

    Args:
        element_plural_name: ([`str`]) the plural word for the values in the container.
        container_name: ([`str`]) the conceptual name of the container.
        missing: the collection of values that are missing.
        actual: the collection of values observed.
        sort: ([`bool`]) if True, then missing and actual are sorted. If False, they
            are not sorted.

    Returns:
        [`tuple`] of ([`str`] problem, [`str`] actual), suitable for passing to ExpectMeta's
        `add_failure()` method.
    """
    missing = maybe_sorted(missing, sort)
    problem_msg = "{count} expected {name} missing from {container}:\n{missing}".format(
        count = len(missing),
        name = element_plural_name,
        container = container_name,
        missing = enumerate_list_as_lines(missing, prefix = "  "),
    )
    actual_msg = format_actual_collection(actual, name = container_name, sort = sort)
    return problem_msg, actual_msg

def format_failure_unexpected_values(*, none_of, unexpected, actual, sort = True):
    """Create error messages when a container has unexpected values.

    Args:
        none_of: ([`str`]) description of the values that were not expected to be
            present.
        unexpected: ([`collection`]) the values that were unexpectedly found.
        actual: ([`collection`]) the observed values.
        sort: ([`bool`]) True if the collections should be sorted for output.

    Returns:
        [`tuple`] of ([`str`] problem, [`str`] actual), suitable for passing to ExpectMeta's
        `add_failure()` method.
    """
    unexpected = maybe_sorted(unexpected, sort)
    problem_msg = "expected not to contain any of: {none_of}\nbut {count} found:\n{unexpected}".format(
        none_of = none_of,
        count = len(unexpected),
        unexpected = enumerate_list_as_lines(unexpected, prefix = "  "),
    )
    actual_msg = format_actual_collection(actual, sort = sort)
    return problem_msg, actual_msg

def format_failure_unexpected_value(container_name, unexpected, actual, sort = True):
    """Create error messages when a container contains a specific unexpected value.

    Args:
        container_name: ([`str`]) conceptual name of the container.
        unexpected: the value that shouldn't have been in `actual`.
        actual: ([`collection`]) the observed values.
        sort: ([`bool`]) True if the collections should be sorted for output.

    Returns:
        [`tuple`] of ([`str`] problem, [`str`] actual), suitable for passing to ExpectMeta's
        `add_failure()` method.
    """
    problem_msg = "expected not to contain: {}".format(unexpected)
    actual_msg = format_actual_collection(actual, name = container_name, sort = sort)
    return problem_msg, actual_msg

def format_problem_dict_expected(
        *,
        expected,
        missing_keys,
        unexpected_keys,
        incorrect_entries,
        container_name = "dict",
        key_plural_name = "keys"):
    """Formats an expected dict, describing what went wrong.

    Args:
        expected: ([`dict`]) the full expected value.
        missing_keys: ([`list`]) the keys that were not found.
        unexpected_keys: ([`list`]) the keys that should not have existed
        incorrect_entries: ([`list`] of [`DictEntryMismatch`]) (see [`_compare_dict`]).
        container_name: ([`str`]) conceptual name of the `expected` dict.
        key_plural_name: ([`str`]) the plural word for the keys of the `expected` dict.
    Returns:
        [`str`] that describes the problem.
    """
    problem_lines = ["expected {}: {{\n{}\n}}".format(
        container_name,
        format_dict_as_lines(expected),
    )]
    if missing_keys:
        problem_lines.append("{count} missing {key_plural_name}:\n{keys}".format(
            count = len(missing_keys),
            key_plural_name = key_plural_name,
            keys = enumerate_list_as_lines(sorted(missing_keys), prefix = "  "),
        ))
    if unexpected_keys:
        problem_lines.append("{count} unexpected {key_plural_name}:\n{keys}".format(
            count = len(unexpected_keys),
            key_plural_name = key_plural_name,
            keys = enumerate_list_as_lines(sorted(unexpected_keys), prefix = "  "),
        ))
    if incorrect_entries:
        problem_lines.append("{} incorrect entries:".format(len(incorrect_entries)))
        for key, mismatch in incorrect_entries.items():
            problem_lines.append("key {}:".format(key))
            problem_lines.append("  expected: {}".format(mismatch.expected))
            problem_lines.append("  but was : {}".format(mismatch.actual))
    return "\n".join(problem_lines)

def format_problem_expected_exactly(expected, sort = True):
    """Creates an error message describing the expected values.

    This is for use when the observed value must have all the values and
    no more.

    Args:
        expected: ([`collection`]) the expected values.
        sort: ([`bool`]) True if to sort the values for display.
    Returns:
        ([`str`]) the formatted problem message
    """
    expected = maybe_sorted(expected, sort)
    return "expected exactly:\n{}".format(
        enumerate_list_as_lines(expected, prefix = "  "),
    )

def format_problem_missing_any_values(any_of, sort = True):
    """Create an error message for when any of a collection of values are missing.

    Args:
        any_of: ([`collection`]) the set of values, any of which were missing.
        sort: ([`bool`]) True if the collection should be sorted for display.
    Returns:
        ([`str`]) the problem description string.
    """
    any_of = maybe_sorted(any_of, sort)
    return "expected to contain any of:\n{}".format(
        enumerate_list_as_lines(any_of, prefix = "  "),
    )

def format_problem_missing_required_values(missing, sort = True):
    """Create an error message for when the missing values must all be present.

    Args:
        missing: ([`collection`]) the values that must all be present.
        sort: ([`bool`]) True if to sort the values for display
    Returns:
        ([`str`]) the problem description string.
    """
    missing = maybe_sorted(missing, sort)
    return "{count} missing:\n{missing}".format(
        count = len(missing),
        missing = enumerate_list_as_lines(missing, prefix = "  "),
    )

def format_problem_predicates_did_not_match(
        missing,
        *,
        element_plural_name = "elements",
        container_name = "values"):
    """Create an error message for when a list of predicates didn't match.

    Args:
        missing: ([`list`] of [`Matcher`]) (see `_match_custom`).
        element_plural_name: ([`str`]) the plural word for the values in the container.
        container_name: ([`str`]) the conceptual name of the container.
    Returns:
        ([`str`]) the problem description string.
    """

    return "{count} expected {name} missing from {container}:\n{missing}".format(
        count = len(missing),
        name = element_plural_name,
        container = container_name,
        missing = enumerate_list_as_lines(
            [m.desc for m in missing],
            prefix = "  ",
        ),
    )

def format_problem_matched_out_of_order(matches):
    """Create an error message for when a expected values matched in the wrong order.

    Args:
        matches: ([`list`] of [`MatchResult`]) see `_check_contains_at_least_predicates()`.
    Returns:
        ([`str`]) the problem description string.
    """
    format_matched_value = guess_format_value([m.matched_value for m in matches])

    def format_value(value):
        # The matcher might be a Matcher object or a plain value.
        # If the matcher description equals the matched value, then we omit
        # the extra matcher text because (1) it'd be redundant, and (2) such
        # matchers are usually wrappers around an underlying value, e.g.
        # how contains_exactly uses matcher predicates.
        if hasattr(value.matcher, "desc") and value.matcher.desc != value.matched_value:
            match_desc = value.matcher.desc
            match_info = " (matched: {})".format(
                format_matched_value(value.matched_value),
            )
            verb = "matched"
        else:
            match_desc = format_matched_value(value.matched_value)
            match_info = ""
            verb = "found"

        return "{match_desc} {verb} at offset {at}{match_info}".format(
            at = value.found_at,
            verb = verb,
            match_desc = match_desc,
            match_info = match_info,
        )

    return "expected values all found, but with incorrect order:\n{}".format(
        enumerate_list_as_lines(matches, format_value = format_value, prefix = "  "),
    )

def format_problem_unexpected_values(unexpected, sort = True):
    """Create an error message for when there are unexpected values.

    Args:
        unexpected: ([`list`]) the unexpected values.
        sort: ([`bool`]) true if the values should be sorted for output.

    Returns:
        ([`str`]) the problem description string.
    """
    unexpected = maybe_sorted(unexpected, sort)
    return "{count} unexpected:\n{unexpected}".format(
        count = len(unexpected),
        unexpected = enumerate_list_as_lines(unexpected, prefix = "  "),
    )

def format_dict_as_lines(mapping, prefix = "", format_value = None, sort = True):
    """Format a dictionary as lines of key->value for easier reading.

    Args:
        mapping: [`dict`] to show
        prefix: ([`str`]) prefix to prepend to every line.
        format_value: (optional callable) takes a value from the dictionary
            to show and returns the string that shown be shown. If not
            specified, one will be automatically determined from the
            dictionary's values.
        sort: ([`bool`]) `True` if the output should be sorted by dict key (if
            the keys are sortable).

    Returns:
        ([`str`]) the dictionary formatted into lines
    """
    lines = []
    if not mapping:
        return "  <empty dict>"
    format_value = guess_format_value(mapping.values())
    keys = maybe_sorted(mapping.keys(), sort)

    max_key_width = max([len(str(key)) for key in keys])

    for key in keys:
        lines.append("{prefix}  {key}{pad}: {value}".format(
            prefix = prefix,
            key = key,
            pad = " " * (max_key_width - len(str(key))),
            value = format_value(mapping[key]),
        ))
    return "\n".join(lines)
