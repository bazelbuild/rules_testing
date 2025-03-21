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

"""Tests for truth.bzl."""

load("//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("//lib:truth.bzl", "matching", "subjects", "truth")
load("//lib:unittest.bzl", ut_asserts = "asserts")

# Bazel 5 has a bug where every access of testing.ExecutionInfo is a new
# object that isn't equal to itself. This is fixed in Bazel 6.
_IS_BAZEL_6_OR_HIGHER = (testing.ExecutionInfo == testing.ExecutionInfo)

_suite = []

def _fake_env(env):
    provider_subject_factories = env.expect.meta.env.provider_subject_factories
    failures = []
    env1 = struct(
        ctx = env.ctx,
        failures = failures,
        fail = lambda msg: failures.append(msg),  # Silent fail
        provider_subject_factories = provider_subject_factories,
    )
    env2 = struct(
        ctx = env.ctx,
        failures = failures,
        fail = lambda msg: failures.append(msg),  # Silent fail
        expect = truth.expect(env1),
        reset = lambda: failures.clear(),
        provider_subject_factories = provider_subject_factories,
    )
    return env2

def _end(env, fake_env):
    _guard_against_stray_failures(env = env, fake_env = fake_env)

def _guard_against_stray_failures(*, env, fake_env):
    ut_asserts.true(
        env,
        len(fake_env.failures) == 0,
        "failures remain: clear after each expected failure\n{}".format(
            "\n".join(fake_env.failures),
        ),
    )

def action_subject_test(name):
    analysis_test(name = name, impl = _action_subject_test, target = "truth_tests_helper")

def _action_subject_test(env, target):
    fake_env = _fake_env(env)
    subject = fake_env.expect.that_target(
        target,
    ).action_named("Action1")

    subject.contains_flag_values([
        ("--arg1flag", "arg1value"),
        ("--arg2flag", "arg2value"),
        ("--generated_input", "{bindir}/{package}/input.gen.txt"),
    ])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check contains_flag_values success",
    )

    subject.argv().contains_at_least([
        "arg1",
        "--boolflag",
        "--arg1flag",
        "arg1value",
        "--arg2flag=arg2value",
        "--generated_input",
        "{bindir}/{package}/input.gen.txt",
    ])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check argv success",
    )

    subject.contains_flag_values([
        ("--missingflag", "whatever"),
        ("--arg1flag", "wrongvalue"),
    ])
    _assert_failure(
        fake_env,
        [
            "2 expected flags with values missing from argv",
            "0: '--arg1flag' with value 'wrongvalue'",
            "1: '--missingflag' (not specified)",
            "actual argv",
            "1: arg1",
            "2: --boolflag",
            "3: --arg1flag",
            "4: arg1value",
            "5: --arg2flag=arg2value",
        ],
        env = env,
        msg = "check contains_flag_values failure",
    )

    subject.contains_none_of_flag_values([
        ("--doesnotexist", "whatever"),
        ("--arg1flag", "differentvalue"),
    ])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check contains_none_of_flag_values success",
    )

    subject.contains_none_of_flag_values([
        ("--arg1flag", "arg1value"),
    ])
    _assert_failure(
        fake_env,
        [
            ("expected not to contain any of: \n" +  # note space after colon
             "  0: '--arg1flag' with value 'arg1value'\n"),
            ("but 1 found:\n" +
             "  0: '--arg1flag' with value 'arg1value'\n"),
            "actual values:\n",
            # Element 0 of actual is omitted because it has build-config
            # specific values within it.
            ("  1: arg1\n" +
             "  2: --boolflag\n" +
             "  3: --arg1flag\n" +
             "  4: arg1value\n" +
             "  5: --arg2flag=arg2value\n"),
        ],
        env = env,
        msg = "check contains_none_of_flag_values failure",
    )
    _end(env, fake_env)

_suite.append(action_subject_test)

def provider_subject_test(name):
    analysis_test(name = name, impl = _provider_subject_test, target = "truth_tests_helper")

_UnusedInfo = provider("unused testing provider", fields = [])

def _provider_subject_test(env, target):
    fake_env = _fake_env(env)
    fake_env.expect.that_target(target).has_provider(_UnusedInfo)
    _assert_failure(
        fake_env,
        ["expected to have provider: <Unknown provider>"],
        env = env,
        msg = "check has_provider() failure uses Unknown provider name",
    )

    fake_env.expect.that_target(target).has_provider(_UnusedInfo, provider_name = "MyInfo")
    _assert_failure(
        fake_env,
        ["expected to have provider: MyInfo"],
        env = env,
        msg = "check has_provider() failure uses supplied provider name",
    )

    def _factory(_unused, meta):
        return struct(
            always_fails = lambda: meta.add_failure("Expected error msg", "Actual error msg"),
        )

    fake_env.expect.that_target(target).provider(_TestHelperInfo, _factory).always_fails()
    _assert_failure(
        fake_env,
        [
            ".provider(<Unknown provider>)",
            "Expected error msg",
            "Actual error msg",
        ],
        env = env,
        msg = "check has_provider() failure uses Unknown provider name",
    )

    fake_env.expect.that_target(target).provider(_TestHelperInfo, _factory, provider_name = "MyInfo").always_fails()
    _assert_failure(
        fake_env,
        [
            ".provider(MyInfo)",
            "Expected error msg",
            "Actual error msg",
        ],
        env = env,
        msg = "check provider() failure uses supplied provider name",
    )

    _end(env, fake_env)

_suite.append(provider_subject_test)

def bool_subject_test(name):
    analysis_test(name = name, impl = _bool_subject_test, target = "truth_tests_helper")

def _bool_subject_test(env, _target):
    fake_env = _fake_env(env)
    fake_env.expect.that_bool(True).equals(True)
    _assert_no_failures(fake_env, env = env)
    fake_env.expect.that_bool(False).equals(False)
    _assert_no_failures(fake_env, env = env)

    fake_env.expect.that_bool(True).equals(False)
    _assert_failure(fake_env, [
        "expected: False",
        "actual: True",
    ], env = env)

    fake_env.expect.that_bool(True, "MYEXPR").equals(False)
    _assert_failure(fake_env, ["MYEXPR"], env = env)

    subject = truth.expect(fake_env).that_bool(True)
    subject.not_equals(True)
    _assert_failure(
        fake_env,
        ["expected not to be: True", "actual: True"],
        env = env,
        msg = "check not_equals fails with same type",
    )
    subject.not_equals(None)
    _assert_failure(
        fake_env,
        ["expected not to be: None (type: NoneType)", "actual: True (type: bool)"],
        env = env,
        msg = "check not_equals due to different type",
    )
    subject.not_equals(False)
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check BoolSubject.not_equals with unequal value of same type",
    )

    subject.is_in([True, False])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check BoolSubject.is_in with matching values",
    )
    subject.is_in([None, 39])
    _assert_failure(
        fake_env,
        ["expected any of:", "None", "39", "actual: True"],
        env = env,
        msg = "check is_in mismatched values",
    )

    _end(env, fake_env)

_suite.append(bool_subject_test)

def collection_custom_expr_test(name):
    analysis_test(name = name, impl = _collection_custom_expr_test, target = "truth_tests_helper")

def _collection_custom_expr_test(env, _target):
    fake_env = _fake_env(env)
    subject = fake_env.expect.that_collection(["a"], "MYEXPR")
    subject.contains_exactly([])
    _assert_failure(fake_env, ["MYEXPR"], env = env)
    _end(env, fake_env)

_suite.append(collection_custom_expr_test)

def collection_has_size_test(name):
    analysis_test(name = name, impl = _collection_has_size_test, target = "truth_tests_helper")

def _collection_has_size_test(env, _target):
    fake_env = _fake_env(env)
    subject = fake_env.expect.that_collection(["a", "b", "c", "d"])

    subject.has_size(4)
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check actual has expected size",
    )

    subject.has_size(0)
    _assert_failure(
        fake_env,
        ["value of: collection.size()"],
        env = env,
        msg = "check actual does not have expected size",
    )

    _end(env, fake_env)

_suite.append(collection_has_size_test)

def collection_contains_test(name):
    analysis_test(name = name, impl = _collection_contains_test, target = "truth_tests_helper")

def _collection_contains_test(env, _target):
    fake_env = _fake_env(env)
    subject = fake_env.expect.that_collection(["a", "b", "c", "d"])

    subject.contains("a")
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check actual does contain expected",
    )

    subject.contains("never")
    _assert_failure(
        fake_env,
        ["expected to contain: never", "actual values", "0: a"],
        env = env,
        msg = "check actual is missing expected",
    )

    _end(env, fake_env)

_suite.append(collection_contains_test)

def collection_contains_predicate_test(name):
    analysis_test(name = name, impl = _collection_contains_predicate_test, target = "truth_tests_helper")

def _collection_contains_predicate_test(env, _target):
    fake_env = _fake_env(env)
    subject = truth.expect(fake_env).that_collection(["a", "b", "c", "d"])

    subject.contains_predicate(matching.contains("a"))
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check actual does contains expected",
    )

    subject.contains_predicate(matching.contains("never"))
    _assert_failure(
        fake_env,
        ["expected to contain: <contains never>", "actual values", "0: a"],
        env = env,
        msg = "check actual is missing a value",
    )
    _end(env, fake_env)

_suite.append(collection_contains_predicate_test)

def collection_contains_at_least_test(name):
    analysis_test(name = name, impl = _collection_contains_at_least_test, target = "truth_tests_helper")

def _collection_contains_at_least_test(env, _target):
    fake_env = _fake_env(env)
    subject = truth.expect(fake_env).that_collection(["a", "b", "c", "d"])

    subject.contains_at_least(["a", "b", "c"]).in_order()
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check expected and actual with same elements in same order",
    )

    subject.contains_at_least(["never"])
    _assert_failure(
        fake_env,
        ["expected elements missing", "never", "actual values", "0: a"],
        env = env,
        msg = "check actual is missing a value",
    )

    subject.contains_at_least([
        "b",
        "a",
    ]).in_order()
    _assert_failure(
        fake_env,
        [
            "incorrect order",
            "0: b found at offset 1",
            "1: a found at offset 0",
        ],
        env = env,
        msg = "check expected values present in wrong order",
    )

    _end(env, fake_env)

_suite.append(collection_contains_at_least_test)

def collection_contains_at_least_predicates_test(name):
    analysis_test(name = name, impl = _collection_contains_at_least_predicates_test, target = "truth_tests_helper")

def _collection_contains_at_least_predicates_test(env, _target):
    fake_env = _fake_env(env)
    subject = truth.expect(fake_env).that_collection(["a", "b", "c", "d"])
    subject.contains_at_least_predicates([
        matching.contains("a"),
        matching.contains("b"),
        matching.contains("c"),
    ]).in_order()

    subject.contains_at_least_predicates([
        matching.never("never"),
    ])
    _assert_failure(
        fake_env,
        ["expected elements missing", "never", "actual values", "0: a"],
        env = env,
    )

    subject.contains_at_least_predicates([
        matching.custom("<MATCHER-B>", lambda v: "b" in v),
        matching.custom("<MATCHER-A>", lambda v: "a" in v),
    ]).in_order()
    _assert_failure(
        fake_env,
        [
            "incorrect order",
            "0: <MATCHER-B> matched at offset 1 (matched: b)",
            "1: <MATCHER-A> matched at offset 0 (matched: a)",
        ],
        env = env,
    )

    _end(env, fake_env)

_suite.append(collection_contains_at_least_predicates_test)

def collection_contains_exactly_test(name):
    analysis_test(name = name, impl = _collection_contains_exactly_test, target = "truth_tests_helper")

def _collection_contains_exactly_test(env, _target):
    fake_env = _fake_env(env)

    subject = truth.expect(fake_env).that_collection([])
    subject.contains_exactly(["a"])
    _assert_failure(
        fake_env,
        [
            "1 missing:\n  0: a",
            "expected exactly:\n  0: a",
            "actual values:\n  <empty>",
        ],
        env = env,
        msg = "check empty actual vs non-empty expected",
    )

    subject = truth.expect(fake_env).that_collection(["b"])
    subject.contains_exactly([])
    _assert_failure(
        fake_env,
        [
            "1 unexpected:\n  0: b",
            "expected exactly:\n  <empty>",
            "actual values:\n  0: b",
        ],
        env = env,
        msg = "check non-empty actual vs empty expected",
    )

    subject = truth.expect(fake_env).that_collection(["c"])
    order = subject.contains_exactly(["c"])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check expected and actual with same elements in same order",
    )
    order.in_order()
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check exact elements are in order",
    )

    subject = truth.expect(fake_env).that_collection(["d"])
    subject.contains_exactly(["e"])
    _assert_failure(
        fake_env,
        [
            "1 missing:\n  0: e",
            "1 unexpected:\n  0: d",
            "expected exactly:\n  0: e",
            "actual values:\n  0: d",
        ],
        env = env,
        msg = "check disjoint values; same length",
    )

    subject = truth.expect(fake_env).that_collection(["f", "g"])
    order = subject.contains_exactly(["g", "f"])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check same elements with expected in different order",
    )
    order.in_order()
    _assert_failure(
        fake_env,
        [
            "expected values all found, but with incorrect order",
            "0: g found at offset 1",
            "1: f found at offset 0",
            "actual values:",
            "0: f",
            "1: g",
        ],
        env = env,
        msg = "check same elements out of order",
    )

    subject = truth.expect(fake_env).that_collection(["x", "y"])
    subject.contains_exactly(["y"])
    _assert_failure(
        fake_env,
        [
            "1 unexpected:\n  0: x",
            "expected exactly:\n  0: y",
            "actual values:\n  0: x\n  1: y",
        ],
        env = env,
        msg = "check expected subset of actual",
    )

    subject = truth.expect(fake_env).that_collection(["a", "b", "c", "d"])
    subject.contains_exactly(["a", "b", "c", "d"])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check expected and actual with exact elements and order; 4 values",
    )

    subject.contains_exactly(["d", "b", "a", "c"])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check expected and actual same elements and different order; 4 values",
    )

    subject = truth.expect(fake_env).that_collection(["a", "b", "a"])
    subject.contains_exactly(["a", "b", "a"])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check multiplicity, same expected/actual order",
    )

    subject.contains_exactly(["b", "a", "a"])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check multiplicity; different expected/actual order",
    )

    subject = truth.expect(fake_env).that_collection([
        "one",
        "two",
        "one",
        "three",
        "one",
        "four",
    ])

    subject.contains_exactly(["one", "two", "three", "five"])
    _assert_failure(
        fake_env,
        [
            ("1 missing:\n" +
             "  0: five"),
            ("3 unexpected:\n" +
             "  0: four\n" +
             "  1: one\n" +
             "  2: one\n"),
            ("expected exactly:\n" +
             "  0: one\n" +
             "  1: two\n" +
             "  2: three\n" +
             "  3: five\n"),
        ],
        env = env,
        msg = "check multiplicity; expected with multiple, expected with unique",
    )

    subject = truth.expect(fake_env).that_collection(["one", "four", "three", "two", "five"])
    order = subject.contains_exactly(["one", "two", "three", "four", "five"])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check same elements with expected in different order",
    )
    order.in_order()
    _assert_failure(
        fake_env,
        [
            "expected values all found, but with incorrect order:",
            "0: one found at offset 0",
            "1: two found at offset 3",
            "2: three found at offset 2",
            "3: four found at offset 1",
            "4: five found at offset 4",
            "actual values:",
            "0: one",
            "1: four",
            "2: three",
            "3: two",
            "4: five",
        ],
        env = env,
        msg = "check same elements out of order",
    )

    subject = truth.expect(fake_env).that_collection(("one", "four", "three", "two", "five"))
    order = subject.contains_exactly(("one", "two", "three", "four", "five"))
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check same elements with expected in different order",
    )
    order.in_order()
    _assert_failure(
        fake_env,
        [
            "expected values all found, but with incorrect order:",
            "0: one found at offset 0",
            "1: two found at offset 3",
            "2: three found at offset 2",
            "3: four found at offset 1",
            "4: five found at offset 4",
            "actual values:",
            "0: one",
            "1: four",
            "2: three",
            "3: two",
            "4: five",
        ],
        env = env,
        msg = "check same elements out of order",
    )

    _end(env, fake_env)

_suite.append(collection_contains_exactly_test)

def collection_contains_exactly_predicates_test(name):
    analysis_test(name = name, impl = _collection_contains_exactly_predicates_test, target = "truth_tests_helper")

def _collection_contains_exactly_predicates_test(env, _target):
    fake_env = _fake_env(env)

    subject = truth.expect(fake_env).that_collection([])
    subject.contains_exactly_predicates([matching.contains("a")])
    _assert_failure(
        fake_env,
        [
            "1 missing:\n  0: <contains a>",
            "expected exactly:\n  0: <contains a>",
            "actual values:\n  <empty>",
        ],
        env = env,
        msg = "check empty actual vs non-empty expected",
    )

    subject = truth.expect(fake_env).that_collection(["b"])
    subject.contains_exactly_predicates([])
    _assert_failure(
        fake_env,
        [
            "1 unexpected:\n  0: b",
            "expected exactly:\n  <empty>",
            "actual values:\n  0: b",
        ],
        env = env,
        msg = "check non-empty actual vs empty expected",
    )

    subject = truth.expect(fake_env).that_collection(["c"])
    order = subject.contains_exactly_predicates([matching.contains("c")])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check expected and actual with same elements in same order",
    )
    order.in_order()
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check exact elements are in order",
    )

    subject = truth.expect(fake_env).that_collection(["d"])
    subject.contains_exactly_predicates([matching.contains("e")])
    _assert_failure(
        fake_env,
        [
            "1 missing:\n  0: <contains e>",
            "1 unexpected:\n  0: d",
            "expected exactly:\n  0: <contains e>",
            "actual values:\n  0: d",
        ],
        env = env,
        msg = "check disjoint values; same length",
    )

    subject = truth.expect(fake_env).that_collection(["f", "g"])
    order = subject.contains_exactly_predicates([
        matching.contains("g"),
        matching.contains("f"),
    ])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check same elements with expected in different order",
    )
    order.in_order()
    _assert_failure(
        fake_env,
        [
            "expected values all found, but with incorrect order",
            "0: <contains g> matched at offset 1 (matched: g)",
            "1: <contains f> matched at offset 0 (matched: f)",
            "actual values:",
            "0: f",
            "1: g",
        ],
        env = env,
        msg = "check same elements out of order",
    )

    subject = truth.expect(fake_env).that_collection(["x", "y"])
    subject.contains_exactly_predicates([matching.contains("y")])
    _assert_failure(
        fake_env,
        [
            "1 unexpected:\n  0: x",
            "expected exactly:\n  0: <contains y>",
            "actual values:\n  0: x\n  1: y",
        ],
        env = env,
        msg = "check expected subset of actual",
    )

    subject = truth.expect(fake_env).that_collection(["a", "b", "c", "d"])
    subject.contains_exactly_predicates([
        matching.contains("a"),
        matching.contains("b"),
        matching.contains("c"),
        matching.contains("d"),
    ])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check expected and actual with exact elements and order; 4 values",
    )

    subject.contains_exactly_predicates([
        matching.contains("d"),
        matching.contains("b"),
        matching.contains("a"),
        matching.contains("c"),
    ])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check expected and actual same elements and different order; 4 values",
    )

    subject = truth.expect(fake_env).that_collection(["a", "b", "a"])
    subject.contains_exactly_predicates([
        matching.contains("a"),
        matching.contains("b"),
        matching.contains("a"),
    ])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check multiplicity, same expected/actual order",
    )

    subject.contains_exactly_predicates([
        matching.contains("b"),
        matching.contains("a"),
        matching.contains("a"),
    ])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check multiplicity; different expected/actual order",
    )

    subject = truth.expect(fake_env).that_collection([
        "one",
        "two",
        "one",
        "three",
        "one",
        "four",
    ])

    subject.contains_exactly_predicates([
        matching.contains("one"),
        matching.contains("two"),
        matching.contains("three"),
        matching.contains("five"),
    ])
    _assert_failure(
        fake_env,
        [
            ("1 missing:\n" +
             "  0: <contains five>"),
            ("3 unexpected:\n" +
             "  0: four\n" +
             "  1: one\n" +
             "  2: one\n"),
            ("expected exactly:\n" +
             "  0: <contains one>\n" +
             "  1: <contains two>\n" +
             "  2: <contains three>\n" +
             "  3: <contains five>\n"),
        ],
        env = env,
        msg = "check multiplicity; expected with multiple, expected with unique",
    )
    _end(env, fake_env)

_suite.append(collection_contains_exactly_predicates_test)

def collection_contains_none_of_test(name):
    analysis_test(name = name, impl = _collection_contains_none_of_test, target = "truth_tests_helper")

def _collection_contains_none_of_test(env, _target):
    fake_env = _fake_env(env)
    subject = truth.expect(fake_env).that_collection(["a"])

    subject.contains_none_of(["b"])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check actual contains none of",
    )

    subject.contains_none_of(["a"])
    _assert_failure(
        fake_env,
        [
            "expected not to contain any of:",
            "  0: a",
            "but 1 found",
            "actual values:",
        ],
        env = env,
        msg = "check actual contains an unexpected value",
    )
    _end(env, fake_env)

_suite.append(collection_contains_none_of_test)

def collection_not_contains_test(name):
    analysis_test(name = name, impl = _collection_not_contains_test, target = "truth_tests_helper")

def _collection_not_contains_test(env, _target):
    fake_env = _fake_env(env)
    subject = truth.expect(fake_env).that_collection(["a"])

    subject.not_contains("b")
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check not_contains passes",
    )
    subject.not_contains("a")
    _assert_failure(
        fake_env,
        [
            "expected not to contain",
            "0: a",
        ],
        env = env,
        msg = "check not_contains fails",
    )

_suite.append(collection_not_contains_test)

def collection_not_contains_predicate_test(name):
    analysis_test(name = name, impl = _collection_not_contains_predicate_test, target = "truth_tests_helper")

def _collection_not_contains_predicate_test(env, _target):
    fake_env = _fake_env(env)
    subject = truth.expect(fake_env).that_collection(["a"])

    subject.not_contains_predicate(matching.contains("b"))
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check actual does not contain a value",
    )

    subject.not_contains_predicate(matching.contains("a"))
    _assert_failure(
        fake_env,
        ["expected not to contain any of: <contains a>", "but 1 found:", "0: a"],
        env = env,
        msg = "check actual contains an unexpected value",
    )
    _end(env, fake_env)

_suite.append(collection_not_contains_predicate_test)

def collection_offset_test(name):
    analysis_test(name = name, impl = _collection_offset_test, target = "truth_tests_helper")

def _collection_offset_test(env, _target):
    fake_env = _fake_env(env)
    subject = truth.expect(fake_env).that_collection(["a", "b", "c"])

    offset_value = subject.offset(0, factory = lambda v, meta: v)
    ut_asserts.true(env, offset_value == "a", "unexpected offset value at 0")

    offset_value = subject.offset(-1, factory = lambda v, meta: v)
    ut_asserts.true(env, offset_value == "c", "unexpected offset value at -1")

    subject.offset(1, factory = subjects.str).equals("not-b")

    _assert_failure(
        fake_env,
        [".offset(1)"],
        env = env,
        msg = "offset error message context not found",
    )

    _end(env, fake_env)

_suite.append(collection_offset_test)

def _collection_transform_test(name):
    analysis_test(name = name, impl = _collection_transform_test_impl, target = "truth_tests_helper")

def _collection_transform_test_impl(env, target):
    _ = target  # @unused
    fake_env = _fake_env(env)
    starter = truth.expect(fake_env).that_collection(["alan", "bert", "cari"])

    actual = starter.transform(
        "values that contain a",
        filter = lambda v: "a" in v,
    )
    actual.contains("not-present")
    _assert_failure(
        fake_env,
        [
            "transform()",
            "0: alan",
            "1: cari",
            "transform: values that contain a",
        ],
        env = env,
        msg = "transform with lambda filter",
    )

    actual = starter.transform(filter = matching.contains("b"))
    actual.contains("not-present")
    _assert_failure(
        fake_env,
        [
            "0: bert",
            "transform: filter=<contains b>",
        ],
        env = env,
        msg = "transform with matcher filter",
    )

    def contains_c(v):
        return "c" in v

    actual = starter.transform(filter = contains_c)
    actual.contains("not-present")
    _assert_failure(
        fake_env,
        [
            "0: cari",
            "transform: filter=contains_c(...)",
        ],
        env = env,
        msg = "transform with named function filter",
    )

    actual = starter.transform(
        "v.upper(); match even offsets",
        map_each = lambda v: "{}-{}".format(v[0], v[1].upper()),
        loop = enumerate,
    )
    actual.contains("not-present")
    _assert_failure(
        fake_env,
        [
            "transform()",
            "0: 0-ALAN",
            "1: 1-BERT",
            "2: 2-CARI",
            "transform: v.upper(); match even offsets",
        ],
        env = env,
        msg = "transform with all args",
    )

    _end(env, fake_env)

_suite.append(_collection_transform_test)

def execution_info_test(name):
    analysis_test(name = name, impl = _execution_info_test, target = "truth_tests_helper")

def _execution_info_test(env, target):
    # TODO(rlevasseur): Remove this after cl/474597236 is released in Blaze
    exec_info_is_ctor = str(testing.ExecutionInfo) == "<function ExecutionInfo>"
    if not exec_info_is_ctor:
        return
    fake_env = _fake_env(env)

    subject = truth.expect(fake_env).that_target(target).provider(testing.ExecutionInfo)
    subject.requirements().contains_exactly({"EIKEY1": "EIVALUE1"})
    _assert_no_failures(fake_env, env = env)
    if _IS_BAZEL_6_OR_HIGHER:
        subject.exec_group().equals("THE_EXEC_GROUP")
    _assert_no_failures(fake_env, env = env)
    _end(env, fake_env)

_suite.append(execution_info_test)

def depset_file_subject_test(name):
    analysis_test(name = name, impl = _depset_file_subject_test, target = "truth_tests_data_files")

def _depset_file_subject_test(env, target):
    fake_env = _fake_env(env)

    # We go through a target so that the usual format_str kwargs are present.
    subject = truth.expect(fake_env).that_target(target).default_outputs()

    # The CollectionSubject tests cover contains_at_least_predicates in
    # more depth, so just do some basic tests here.
    subject.contains_at_least_predicates([
        matching.file_path_matches("txt"),
    ])
    _assert_no_failures(fake_env, env = env)

    subject.contains_at_least_predicates([
        matching.file_path_matches("NOT THERE"),
    ])
    _assert_failure(
        fake_env,
        ["NOT THERE", "file1.txt"],
        env = env,
    )

    subject.contains_predicate(matching.file_path_matches("txt"))
    _assert_no_failures(fake_env, env = env)
    subject.contains_predicate(matching.file_path_matches("NOT THERE"))
    _assert_failure(
        fake_env,
        ["NOT THERE", "file1.txt"],
        env = env,
    )

    subject.contains_exactly(["{package}/testdata/file1.txt"])
    _assert_no_failures(fake_env, env = env)
    subject.contains_exactly(["NOT THERE"])
    _assert_failure(
        fake_env,
        ["NOT THERE", "file1.txt"],
        env = env,
    )

    subject.not_contains("does-not-contain")
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "DepsetFilesubject.not_contains success test",
    )
    subject.not_contains("{package}/testdata/file1.txt")
    _assert_failure(
        fake_env,
        ["expected not to contain any of", "file1.txt"],
        env = env,
        msg = "DepsetFilesubject.not_contains failure test",
    )

    _end(env, fake_env)

_suite.append(depset_file_subject_test)

def dict_subject_test(name):
    analysis_test(name = name, impl = _dict_subject_test, target = "truth_tests_helper")

def _dict_subject_test(env, _target):
    fake_env = _fake_env(env)
    subject = truth.expect(fake_env).that_dict({"a": 1, "b": 2, "c": 3})

    def factory(value, *, meta):
        return struct(value = value, meta = meta)

    actual = subject.get("a", factory = factory)

    truth.expect(env).that_int(actual.value).equals(1)
    truth.expect(env).that_collection(actual.meta._exprs).contains("get(a)")

    subject.contains_exactly({"a": 1, "b": 2, "c": 3})
    _assert_no_failures(fake_env, env = env)

    subject.contains_exactly({"d": 4, "a": 99})
    _assert_failure(
        fake_env,
        [
            ("expected dict: {\n" +
             "  a: <int 99>\n" +
             "  d: <int 4>\n" +
             "}\n"),
            ("1 missing keys:\n" +
             "  0: d\n"),
            ("2 unexpected keys:\n" +
             "  0: b\n" +
             "  1: c\n"),
            ("1 incorrect entries:\n" +
             "key a:\n" +
             "  expected: 99\n" +
             "  but was : 1\n"),
            ("actual: {\n" +
             "  a: <int 1>\n" +
             "  b: <int 2>\n" +
             "  c: <int 3>\n" +
             "}\n"),
        ],
        env = env,
    )

    subject.contains_at_least({"a": 1})
    _assert_no_failures(fake_env, env = env)

    subject.contains_at_least({"d": 91, "a": 74})
    _assert_failure(
        fake_env,
        [
            ("expected dict: {\n" +
             "  a: <int 74>\n" +
             "  d: <int 91>\n" +
             "}\n"),
            ("1 missing keys:\n" +
             "  0: d\n"),
            ("1 incorrect entries:\n" +
             "key a:\n" +
             "  expected: 74\n" +
             "  but was : 1\n"),
            ("actual: {\n" +
             "  a: <int 1>\n" +
             "  b: <int 2>\n" +
             "  c: <int 3>\n" +
             "}\n"),
        ],
        env = env,
    )

    # NOTE: we use the real env for this, since we're doing a real assert
    truth.expect(env).that_collection(
        subject.keys().actual,
    ).contains_exactly(["a", "b", "c"])

    _end(env, fake_env)

_suite.append(dict_subject_test)

def expect_test(name):
    analysis_test(name = name, impl = _expect_test, target = "truth_tests_helper")

def _expect_test(env, target):
    fake_env = _fake_env(env)
    expect = truth.expect(fake_env)

    ut_asserts.true(
        env,
        expect.that_target(target) != None,
        msg = "expect.that_target",
    )
    _assert_no_failures(fake_env, env = env)

    expect.where(
        foo = "bar",
        baz = "qux",
    ).that_bool(True).equals(False)
    _assert_failure(
        fake_env,
        ["foo: bar", "baz: qux"],
        env = env,
    )
    _end(env, fake_env)

_suite.append(expect_test)

def file_subject_test(name):
    analysis_test(name = name, impl = _file_subject_test, target = "truth_tests_data_files")

def _file_subject_test(env, target):
    fake_env = _fake_env(env)
    package = target.label.package
    expect = truth.expect(fake_env)
    subject = expect.that_file(target.files.to_list()[0])
    subject.short_path_equals(package + "/testdata/file1.txt")
    subject.basename().equals("file1.txt")
    _assert_no_failures(fake_env, env = env)

    subject.short_path_equals("landon-and-hope-forever.txt")
    _assert_failure(
        fake_env,
        [
            "value of: file",
            "expected: landon-and-hope-forever.txt",
            "actual: {}/testdata/file1.txt".format(package),
        ],
        env = env,
    )

    subject = expect.that_file(
        target.files.to_list()[0],
        meta = expect.meta.derive(
            format_str_kwargs = {"custom": "file1.txt"},
        ),
    )

    # NOTE: We purposefully don't use `{package}` because we're just
    # testing the `{custom}` keyword
    subject.short_path_equals(package + "/testdata/{custom}")
    _assert_no_failures(fake_env, env = env)

    _end(env, fake_env)

_suite.append(file_subject_test)

def label_subject_test(name):
    analysis_test(name = name, impl = _label_subject_test, target = "truth_tests_helper")

def _label_subject_test(env, target):
    fake_env = _fake_env(env)

    expect = truth.expect(fake_env)
    subject = expect.that_target(target).label()

    subject.equals("//tests:truth_tests_helper")
    _assert_no_failures(fake_env, env = env)

    subject.equals(Label("//tests:truth_tests_helper"))
    _assert_no_failures(fake_env, env = env)

    subject.equals("//nope")
    _assert_failure(
        fake_env,
        ["expected: " + str(Label("//nope")), "actual:", "_helper"],
        env = env,
    )

    subject = subjects.label(Label("//some/pkg:label"), expect.meta)
    subject.is_in(["//foo:bar", "//some/pkg:label"])
    _assert_no_failures(fake_env, msg = "is_in with matched str values", env = env)
    subject.is_in([Label("//bar:baz"), Label("//some/pkg:label")])
    _assert_no_failures(fake_env, msg = "is_in with matched label values", env = env)
    subject.is_in(["//not:there", Label("//other:value")])
    _assert_failure(
        fake_env,
        [
            "expected any of:",
            "//not:there",
            "//other:value",
            "actual: " + str(Label("//some/pkg:label")),
        ],
        msg = "check is_in fails",
        env = env,
    )

    _end(env, fake_env)

_suite.append(label_subject_test)

def runfiles_subject_test(name):
    analysis_test(name = name, impl = _runfiles_subject_test, target = "truth_tests_helper")

def _runfiles_subject_test(env, target):
    fake_env = _fake_env(env)

    subject = truth.expect(fake_env).that_target(target).runfiles()
    subject.contains("{workspace}/{package}/default_runfile1.txt")
    _assert_no_failures(fake_env, env = env)

    subject.contains("does-not-exist")
    _assert_failure(
        fake_env,
        [
            "expected to contain: does-not-exist",
            "actual default runfiles:",
            "default_runfile1.txt",
            "target: {}".format(target.label),
        ],
        env = env,
        msg = "check contains",
    )

    subject.contains_none_of(["{workspace}/{package}/not-there.txt"])
    _assert_no_failures(fake_env, env = env)

    subject.contains_none_of(["{workspace}/{package}/default_runfile1.txt"])
    _assert_failure(
        fake_env,
        [
            "expected not to contain any of",
            "default_runfile1.txt",
            env.ctx.workspace_name,
        ],
        env = env,
        msg = "check contains none of",
    )

    subject.contains_exactly([
        "{workspace}/{package}/default_runfile1.txt",
        "{workspace}/{package}/truth_tests_helper.txt",
    ])
    _assert_no_failures(fake_env, env = env)
    subject.contains_exactly([
        "{workspace}/{package}/not-there.txt",
    ])
    _assert_failure(
        fake_env,
        [
            "1 missing",
            "not-there.txt",
            env.ctx.workspace_name,
        ],
        env = env,
        msg = "check contains_exactly fails",
    )

    subject.contains_exactly_predicates([
        matching.str_matches("runfile1.txt"),
        matching.str_matches("helper.txt"),
    ])
    _assert_no_failures(fake_env, env = env)
    subject.contains_exactly_predicates([
        matching.str_matches("runfile1.txt"),
        matching.str_matches("does-not-match"),
    ])
    _assert_failure(
        fake_env,
        [
            "1 missing",
            "<matches 'does-not-match'>",
        ],
        env = env,
        msg = "check contains_exactly_predicates",
    )

    subject.contains_at_least([
        "{workspace}/{package}/default_runfile1.txt",
    ])
    _assert_no_failures(fake_env, env = env)
    subject.contains_at_least([
        "not-there.txt",
    ])
    _assert_failure(
        fake_env,
        [
            "1 expected paths missing",
            "not-there.txt",
            env.ctx.workspace_name,
        ],
        env = env,
        msg = "check contains_at_least fails",
    )

    subject.contains_at_least_predicates([
        matching.str_matches("runfile1.txt"),
    ])
    _assert_no_failures(fake_env, env = env)
    subject.contains_at_least_predicates([
        matching.str_matches("does-not-match"),
    ])
    _assert_failure(
        fake_env,
        [
            "1 expected paths missing",
            "<matches 'does-not-match'>",
        ],
        env = env,
        msg = "check contains_at_least_predicates",
    )

    subject.paths().contains_predicate(matching.str_matches("runfile1.txt"))
    _assert_no_failures(fake_env, env = env)

    _end(env, fake_env)

_suite.append(runfiles_subject_test)

def str_subject_test(name):
    analysis_test(name = name, impl = _str_subject_test, target = "truth_tests_helper")

def _str_subject_test(env, _target):
    fake_env = _fake_env(env)
    subject = truth.expect(fake_env).that_str("foobar")

    subject.contains("ob")
    _assert_no_failures(fake_env, env = env)

    subject.contains("nope")
    _assert_failure(
        fake_env,
        ["expected to contain: nope", "actual: foobar"],
        env = env,
        msg = "check contains",
    )

    subject.equals("foobar")
    _assert_no_failures(fake_env, env = env)

    subject.equals("not foobar")
    _assert_failure(
        fake_env,
        ["expected: not foobar", "actual: foobar"],
        env = env,
        msg = "check equals",
    )

    result = subject.split("b")
    ut_asserts.true(env, result.actual == ["foo", "ar"], "incorrectly split")

    subject.not_equals("foobar")
    _assert_failure(
        fake_env,
        ["expected not to be: foobar", "actual: foobar"],
        env = env,
        msg = "check not_equals with equal value",
    )
    subject.not_equals(47)
    _assert_failure(
        fake_env,
        ["expected not to be: 47 (type: int)", "actual: foobar (type: string)"],
        env = env,
        msg = "check not_equals with different type",
    )
    subject.not_equals("not-foobar")
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check not_equals with unequal value of same type",
    )

    subject.is_in(["xxx", "yyy", "zzz"])
    _assert_failure(
        fake_env,
        ["expected any of:", "xxx", "yyy", "zzz", "actual: foobar"],
        env = env,
        msg = "check is_in with non-matching values",
    )
    subject.is_in(["foobar", "y", "z"])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check is_in with matching values",
    )
    _end(env, fake_env)

_suite.append(str_subject_test)

def struct_subject_test(name):
    analysis_test(name = name, impl = _struct_subject_test, target = "truth_tests_helper")

def _struct_subject_test(env, _target):
    fake_env = _fake_env(env)
    subject = truth.expect(fake_env).that_struct(
        struct(a = "a"),
        attrs = {"a": subjects.str},
    )

    subject.a().equals("a")
    _assert_no_failures(fake_env, env = env)

    _end(env, fake_env)

_suite.append(struct_subject_test)

def custom_subject_test(name):
    analysis_test(name = name, impl = _custom_subject_test, target = "truth_tests_helper")

def _custom_subject_test(env, _target):
    fake_env = _fake_env(env)
    subject = truth.expect(fake_env).that_value(
        ["a"],
        factory = subjects.collection,
    )

    subject.contains_exactly(["a"])
    _assert_no_failures(fake_env, env = env)

    _end(env, fake_env)

_suite.append(custom_subject_test)

def target_subject_test(name):
    analysis_test(name = name, impl = _target_subject_test, target = "truth_tests_helper")  #TODO also file target

def _target_subject_test(env, target):
    fake_env = _fake_env(env)
    subject = truth.expect(fake_env).that_target(target)

    # First a static string, no formatting parameters
    result = subject.action_generating("{package}/default_runfile1.txt")
    ut_asserts.true(env, result != None, msg = "action_generating gave None")

    # Now try it with formatting parameters
    result = subject.action_generating("{package}/{name}.txt")
    ut_asserts.true(env, result != None, msg = "action_generating gave None")

    result = subject.label()
    ut_asserts.true(env, result != None, msg = "label gave None")

    subject = truth.expect(fake_env).that_target(target)

    tags = subject.tags()
    ut_asserts.true(env, tags != None, msg = "tags gave None")

    tags.contains_exactly(["tag1", "tag2"])
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check TargetSubject.tags()",
    )

    attr_subject = subject.attr("testonly")
    ut_asserts.true(env, attr_subject != None, msg = "attr(testonly) gave None")

    custom_subject = subject.attr(
        "testonly",
        factory = lambda v, meta: struct(custom = True),
    )
    ut_asserts.true(
        env,
        custom_subject.custom == True,
        msg = "attr() with custom factory gave wrong value",
    )

    output_group_subject = subject.output_group("some_group")
    output_group_subject.contains("{package}/output_group_file.txt")
    _assert_no_failures(
        fake_env,
        env = env,
        msg = "check TargetSubject.output_group()",
    )

    _end(env, fake_env)

_suite.append(target_subject_test)

def run_environment_info_subject_test(name):
    analysis_test(name = name, impl = _run_environment_info_subject_test, target = "truth_tests_helper")

def _run_environment_info_subject_test(env, target):
    fake_env = _fake_env(env)

    subject = truth.expect(fake_env).that_target(target).provider(
        RunEnvironmentInfo,
    )

    subject.environment().contains_exactly({
        "EKEY1": "EVALUE1",
        "EKEY2": "EVALUE2",
    })
    _assert_no_failures(fake_env, env = env)

    subject.inherited_environment().contains_exactly(["INHERIT1", "INHERIT2"])
    _assert_no_failures(fake_env, env = env)

    _end(env, fake_env)

_suite.append(run_environment_info_subject_test)

def _add_failure_works_test(name):
    analysis_test(
        name = name,
        impl = _add_failure_works_test_impl,
        target = "truth_tests_noop",
        expect_failure = True,
    )

def _add_failure_works_test_impl(env, target):
    """Test that the real add_failure() codepath works.

    All the other tests mock out the fail() call, this is the one test that doesn't.
    """
    _ = target  # @unused

    # NOTE: this prints a spurious message.
    env.expect.meta.add_failure("FAKE PROBLEM", "FAKE ACTUAL")

    failures = list(env._failures)
    env._failures.clear()

    if len(failures) != 1:
        env.fail("Expected len(failures) == 1, got " + str(len(failures)))
    else:
        failure = failures[0]
        if "FAKE PROBLEM" not in failure:
            env.fail("Expected string 'FAKE PROBLEM' not found in failure message")
        if "FAKE ACTUAL" not in failure:
            env.fail("Expected string 'FAKE ACTUAL' not found in failure message")

_suite.append(_add_failure_works_test)

def _assert_no_failures(fake_env, *, env, msg = ""):
    fail_lines = [
        "expected no failures, but found failures",
        msg,
        "===== FAILURE MESSAGES =====",
    ]
    fail_lines.extend(fake_env.failures)
    fail_lines.append("===== END FAILURE MESSAGES ====")
    fail_msg = "\n".join(fail_lines)
    ut_asserts.true(env, len(fake_env.failures) == 0, msg = fail_msg)
    fake_env.reset()

def _assert_failure(fake_env, expected_strs, *, env, msg = ""):
    if len(fake_env.failures) != 1:
        env.fail("expected exactly 1 failure, but found {}".format(len(fake_env.failures)))

    if len(fake_env.failures) > 0:
        failure = fake_env.failures[0]
        for expected in expected_strs:
            if expected not in failure:
                env.fail((
                    "\nFailure message incorrect:\n{}\n" +
                    "===== EXPECTED ERROR SUBSTRING =====\n{}\n" +
                    "===== END EXPECTED ERROR SUBSTRING =====\n" +
                    "===== ACTUAL FAILURE MESSAGE =====\n{}\n" +
                    "===== END ACTUAL FAILURE MESSAGE ====="
                ).format(
                    msg,
                    expected,
                    failure,
                ))

    fake_env.reset()

_TestHelperInfo = provider("empty provider for testing", fields = [])

def _test_helper_impl(ctx):
    action_output = ctx.actions.declare_file("action.txt")
    generated_input = _empty_file(ctx, "input.gen.txt")
    args = ctx.actions.args()
    args.add("arg1")
    args.add("--boolflag")
    args.add("--arg1flag", "arg1value")
    args.add("arg2value", format = "--arg2flag=%s")
    args.add("--generated_input", generated_input)
    ctx.actions.run(
        inputs = [generated_input],
        outputs = [action_output],
        executable = ctx.executable.tool,
        arguments = [args],
        mnemonic = "Action1",
    )
    if _IS_BAZEL_6_OR_HIGHER:
        exec_info_bazel_6_kwargs = {"exec_group": "THE_EXEC_GROUP"}
    else:
        exec_info_bazel_6_kwargs = {}

    return [
        DefaultInfo(
            default_runfiles = ctx.runfiles(
                files = [
                    _empty_file(ctx, "default_runfile1.txt"),
                    _empty_file(ctx, ctx.label.name + ".txt"),
                ],
            ),
        ),
        testing.TestEnvironment(
            environment = {"EKEY1": "EVALUE1", "EKEY2": "EVALUE2"},
            inherited_environment = ["INHERIT1", "INHERIT2"],
        ),
        testing.ExecutionInfo({"EIKEY1": "EIVALUE1"}, **exec_info_bazel_6_kwargs),
        OutputGroupInfo(
            some_group = depset([_empty_file(ctx, "output_group_file.txt")]),
        ),
        _TestHelperInfo(),
    ]

test_helper = rule(
    implementation = _test_helper_impl,
    attrs = {
        "tool": attr.label(
            default = ":truth_tests_noop",
            executable = True,
            cfg = "exec",
        ),
    },
)

def _empty_file(ctx, name):
    file = ctx.actions.declare_file(name)
    ctx.actions.write(file, content = "")
    return file

def _noop_binary_impl(ctx):
    return DefaultInfo(executable = _empty_file(ctx, ctx.label.name))

noop_binary = rule(
    implementation = _noop_binary_impl,
    executable = True,
)

def truth_test_suite(name):
    # Unit tests can't directly create File objects, so we have a generic
    # collection of files they can put in custom attributes to use.
    native.filegroup(
        name = "truth_tests_data_files",
        srcs = native.glob(["testdata/**"]),
    )
    test_helper(
        name = "truth_tests_helper",
        tags = ["tag1", "tag2"],
    )
    noop_binary(name = "truth_tests_noop")

    test_suite(
        name = name,
        tests = _suite,
    )
