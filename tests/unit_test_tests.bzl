"""Tests for unit_test."""

load("//lib:test_suite.bzl", "test_suite")
load("//lib:unit_test.bzl", "unit_test")

def _test_basic(env):
    _ = env  # @unused

def _test_with_setup(name):
    unit_test(
        name = name,
        impl = _test_with_setup_impl,
        attrs = {"custom_attr": attr.string(default = "default")},
    )

def _test_with_setup_impl(env):
    env.expect.that_str(env.ctx.attr.custom_attr).equals("default")

def unit_test_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _test_with_setup,
        ],
        basic_tests = [
            _test_basic,
        ],
    )
