"""Tests for matchers."""

load("//lib:test_suite.bzl", "test_suite")
load("//lib:truth.bzl", "matching")

_tests = []

def _file(path):
    _, _, basename = path.rpartition("/")
    _, _, extension = basename.rpartition(".")
    return struct(
        path = path,
        basename = basename,
        extension = extension,
    )

def _verify_matcher(env, matcher, match_true, match_false):
    # Test postive match
    env.expect.where(matcher = matcher.desc, value = match_true).that_bool(
        matcher.match(match_true),
        expr = "matcher.match(value)",
    ).equals(True)

    # Test negative match
    env.expect.where(matcher = matcher.desc, value = match_false).that_bool(
        matcher.match(match_false),
        expr = "matcher.match(value)",
    ).equals(False)

def _contains_test(env):
    _verify_matcher(
        env,
        matching.contains("x"),
        match_true = "YYYxZZZ",
        match_false = "zzzzz",
    )

_tests.append(_contains_test)

def _file_basename_equals_test(env):
    _verify_matcher(
        env,
        matching.file_basename_equals("bar.txt"),
        match_true = _file("foo/bar.txt"),
        match_false = _file("foo/bar.md"),
    )

_tests.append(_file_basename_equals_test)

def _file_extension_in_test(env):
    _verify_matcher(
        env,
        matching.file_extension_in(["txt", "rst"]),
        match_true = _file("foo.txt"),
        match_false = _file("foo.py"),
    )

_tests.append(_file_extension_in_test)

def _is_in_test(env):
    _verify_matcher(
        env,
        matching.is_in(["a", "b"]),
        match_true = "a",
        match_false = "z",
    )

_tests.append(_is_in_test)

def _str_matchers_test(env):
    _verify_matcher(
        env,
        matching.str_matches("f*b"),
        match_true = "foobar",
        match_false = "nope",
    )

    _verify_matcher(
        env,
        matching.str_endswith("123"),
        match_true = "abc123",
        match_false = "123xxx",
    )

    _verify_matcher(
        env,
        matching.str_startswith("true"),
        match_true = "truechew",
        match_false = "notbuck",
    )

_tests.append(_str_matchers_test)

def matching_test_suite(name):
    test_suite(
        name = name,
        basic_tests = _tests,
    )
