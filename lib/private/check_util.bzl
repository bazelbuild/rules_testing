"""Helper functions to perform checks."""

load("@bazel_skylib//lib:types.bzl", "types")
load(":compare_util.bzl", "MatchResult", "compare_contains_exactly_predicates")
load(":failure_messages.bzl", "format_failure_unexpected_values")
load(":matching.bzl", "matching")
load(":ordered.bzl", "IN_ORDER", "OrderedIncorrectly")
load(":truth_common.bzl", "enumerate_list_as_lines", "maybe_sorted", "to_list")

def check_contains_exactly(
        *,
        expect_contains,
        actual_container,
        format_actual,
        format_expected,
        format_missing,
        format_unexpected,
        format_out_of_order,
        meta):
    """Check that a collection contains exactly the given values and no more.

    This checks that the collection contains exactly the given values. Extra
    values are not allowed. Multiplicity of the expected values is respected.
    Ordering is not checked; call `in_order()` to also check the order
    of the actual values matches the order of the expected values.

    Args:
        expect_contains: the values that must exist (and no more).
        actual_container: the values to check within.
        format_actual: (callable) accepts no args and returns [`str`] (the
            description of the actual values).
        format_expected: (callable) accepts no args and returns [`str`] (
            description of the expected values).
        format_missing: (callable) accepts 1 position arg (list of values from
            `expect_contains` that were missing), and returns [`str`] (description of
            the missing values).
        format_unexpected: (callable) accepts 1 positional arg (list of values from
           `actual_container` that weren't expected), and returns [`str`] (description of
           the unexpected values).
        format_out_of_order: (callable) accepts 1 arg (a list of "MatchResult"
            structs, see above) and returns a string (the problem message
            reported on failure). The order of match results is the expected
            order.
        meta: ([`ExpectMeta`]) to record failures.

    Returns:
        [`Ordered`] object.
    """
    result = compare_contains_exactly_predicates(
        expect_contains = [
            matching.equals_wrapper(raw_expected)
            for raw_expected in expect_contains
        ],
        actual_container = actual_container,
    )
    if not result.contains_exactly:
        problems = []
        if result.missing:
            problems.append(format_missing([m.desc for m in result.missing]))
        if result.unexpected:
            problems.append(format_unexpected(result.unexpected))
        problems.append(format_expected())

        meta.add_failure("\n".join(problems), format_actual())

        # We already recorded an error, so just pretend order is correct to
        # avoid spamming another error.
        return IN_ORDER
    elif result.is_in_order:
        return IN_ORDER
    else:
        return OrderedIncorrectly.new(
            format_problem = lambda: format_out_of_order(result.matches),
            format_actual = format_actual,
            meta = meta,
        )

def check_contains_exactly_predicates(
        *,
        expect_contains,
        actual_container,
        format_actual,
        format_expected,
        format_missing,
        format_unexpected,
        format_out_of_order,
        meta):
    """Check that a collection contains values matching the given predicates and no more.

    todo doc to describe behavior
    This checks that the collection contains values that match the given exactly the given values.
    Extra values that do not match a predicate are not allowed. Multiplicity of
    the expected predicates is respected. Ordering is not checked; call
    `in_order()` to also check the order of the actual values matches the order
    of the expected predicates.

    Args:
        expect_contains: the predicates that must match (and no more).
        actual_container: the values to check within.
        format_actual: (callable) accepts no args and returns [`str`] (the
            description of the actual values).
        format_expected: (callable) accepts no args and returns [`str`] (
            description of the expected values).
        format_missing: (callable) accepts 1 position arg (list of values from
            `expect_contains` that were missing), and returns [`str`] (description of
            the missing values).
        format_unexpected: (callable) accepts 1 positional arg (list of values from
           `actual_container` that weren't expected), and returns [`str`] (description of
           the unexpected values).
        format_out_of_order: (callable) accepts 1 arg (a list of "MatchResult"
            structs, see above) and returns a string (the problem message
            reported on failure). The order of match results is the expected
            order.
        meta: ([`ExpectMeta`]) to record failures.

    Returns:
        [`Ordered`] object.
    """
    result = compare_contains_exactly_predicates(
        expect_contains = expect_contains,
        actual_container = actual_container,
    )
    if not result.contains_exactly:
        problems = []
        if result.missing:
            problems.append(format_missing(result.missing))
        if result.unexpected:
            problems.append(format_unexpected(result.unexpected))
        problems.append(format_expected())

        meta.add_failure("\n".join(problems), format_actual())

        # We already recorded an error, so just pretend order is correct to
        # avoid spamming another error.
        return IN_ORDER
    elif result.is_in_order:
        return IN_ORDER
    else:
        return OrderedIncorrectly.new(
            format_problem = lambda: format_out_of_order(result.matches),
            format_actual = format_actual,
            meta = meta,
        )

def check_contains_predicate(collection, matcher, *, format_problem, format_actual, meta):
    """Check that `matcher` matches any value in `collection`, and record an error if not.

    Args:
        collection: ([`collection`]) the collection whose values are compared against.
        matcher: ([`Matcher`]) that must match.
        format_problem: ([`str`] |  callable) If a string, then the problem message
            to use when failing. If a callable, a no-arg callable that returns
            the problem string; see `_format_problem_*` for existing helpers.
        format_actual: ([`str`] |  callable) If a string, then the actual message
            to use when failing. If a callable, a no-arg callable that returns
            the actual string; see `_format_actual_*` for existing helpers.
        meta: ([`ExpectMeta`]) to record failures
    """
    for value in collection:
        if matcher.match(value):
            return
    meta.add_failure(
        format_problem if types.is_string(format_problem) else format_problem(),
        format_actual if types.is_string(format_actual) else format_actual(),
    )

def check_contains_at_least_predicates(
        collection,
        matchers,
        *,
        format_missing,
        format_out_of_order,
        format_actual,
        meta):
    """Check that the collection is a subset of the predicates.

    The collection must match all the predicates. It can contain extra elements.
    The multiplicity of matchers is respected. Checking that the relative order
    of matches is the same as the passed-in matchers order can done by calling
    `in_order()`.

    Args:
        collection: [`collection`] of values to check within.
        matchers: [`collection`] of [`Matcher`] objects to match (see `matchers` struct)
        format_missing: (callable) accepts 1 positional arg (a list of the
            `matchers` that did not match) and returns a string (the problem
            message reported on failure).
        format_out_of_order: (callable) accepts 1 arg (a list of `MatchResult`s)
            and returns a string (the problem message reported on failure). The
            order of match results is the expected order.
        format_actual: callable: accepts no args and returns a string (the
            text describing the actual value reported on failure).
        meta: ([`ExpectMeta`]) used for reporting errors.

    Returns:
        [`Ordered`] object to allow checking the order of matches.
    """

    # We'll later update this list in-place with results. We keep the order
    # so that, on failure, the formatters receive the expected order of matches.
    matches = [None for _ in matchers]

    # A list of (original position, matcher) tuples. This allows
    # mapping a matcher back to its original order and respecting
    # the multiplicity of matchers.
    remaining_matchers = enumerate(matchers)
    ordered = True
    for absolute_pos, value in enumerate(collection):
        if not remaining_matchers:
            break
        found_i = -1
        for cur_i, (_, matcher) in enumerate(remaining_matchers):
            if matcher.match(value):
                found_i = cur_i
                break
        if found_i > -1:
            ordered = ordered and (found_i == 0)
            orig_matcher_pos, matcher = remaining_matchers.pop(found_i)
            matches[orig_matcher_pos] = MatchResult.new(
                matched_value = value,
                found_at = absolute_pos,
                matcher = matcher,
            )

    if remaining_matchers:
        meta.add_failure(
            format_missing([v[1] for v in remaining_matchers]),
            format_actual if types.is_string(format_actual) else format_actual(),
        )

        # We've added a failure, so no need to spam another error message, so
        # just pretend things are in order.
        return IN_ORDER
    elif ordered:
        return IN_ORDER
    else:
        return OrderedIncorrectly.new(
            format_problem = lambda: format_out_of_order(matches),
            format_actual = format_actual,
            meta = meta,
        )

def check_contains_none_of(*, collection, none_of, meta, sort = True):
    """Check that a collection does not have any of the `none_of` values.

    Args:
        collection: ([`collection`]) the values to check within.
        none_of: the values that should not exist.
        meta: ([`ExpectMeta`]) to record failures.
        sort: ([`bool`]) If true, sort the values for display.
    """
    unexpected = []
    for value in none_of:
        if value in collection:
            unexpected.append(value)
    if not unexpected:
        return

    unexpected = maybe_sorted(unexpected, sort)
    problem, actual = format_failure_unexpected_values(
        none_of = "\n" + enumerate_list_as_lines(unexpected, prefix = "  "),
        unexpected = unexpected,
        actual = collection,
        sort = sort,
    )
    meta.add_failure(problem, actual)

def check_not_contains_predicate(collection, matcher, *, meta, sort = True):
    """Check that `matcher` matches no values in `collection`.

    Args:
        collection: ([`collection`]) the collection whose values are compared against.
        matcher: ([`Matcher`]) that must not match.
        meta: ([`ExpectMeta`]) to record failures
        sort: ([`bool`]) If `True`, the collection will be sorted for display.
    """
    matches = maybe_sorted([v for v in collection if matcher.match(v)], sort)
    if not matches:
        return
    problem, actual = format_failure_unexpected_values(
        none_of = matcher.desc,
        unexpected = matches,
        actual = collection,
        sort = sort,
    )
    meta.add_failure(problem, actual)

def common_subject_is_in(self, any_of):
    """Generic implementation of `Subject.is_in`

    Args:
        self: The subject object. It must provide `actual` and `meta`
            attributes.
        any_of: [`collection`] of values.
    """
    return _check_is_in(self.actual, to_list(any_of), self.meta)

def _check_is_in(actual, any_of, meta):
    """Check that `actual` is one of the values in `any_of`.

    Args:
        actual: value to check for in `any_of`
        any_of: [`collection`] of values to check within.
        meta: ([`ExpectMeta`]) to record failures
    """
    if actual in any_of:
        return
    meta.add_failure(
        "expected any of:\n{}".format(
            enumerate_list_as_lines(any_of, prefix = "  "),
        ),
        "actual: {}".format(actual),
    )

def check_not_equals(*, unexpected, actual, meta):
    """Check that the values are the same type and not equal (according to !=).

    NOTE: This requires the same type for both values. This is to prevent
    mistakes where different data types (usually) can never be equal.

    Args:
        unexpected: (object) the value that actual cannot equal
        actual: (object) the observed value
        meta: ([`ExpectMeta`]) to record failures
    """
    same_type = type(actual) == type(unexpected)
    equal = not (actual != unexpected)  # Use != to preserve semantics
    if same_type and not equal:
        return
    if not same_type:
        meta.add_failure(
            "expected not to be: {} (type: {})".format(unexpected, type(unexpected)),
            "actual: {} (type: {})".format(actual, type(actual)),
        )
    else:
        meta.add_failure(
            "expected not to be: {}".format(unexpected),
            "actual: {}".format(actual),
        )
