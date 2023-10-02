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

"""Utilities for testing rules_testing code."""

load("//lib:truth.bzl", "matching")

# buildifier: disable=bzl-visibility
load("//lib/private:expect_meta.bzl", "ExpectMeta")

def _fake_meta(real_env):
    """Create a fake ExpectMeta object for testing.

    The fake ExpectMeta object copies a real ExpectMeta object, except:
      * Failures are only recorded and don't cause a failure in `real_env`.
      * `failures` attribute is added; this is a list of failures seen.
      * `reset` attribute is added; this clears the failures list.

    Args:
        real_env: A real env object from the rules_testing framework.

    Returns:
        struct, a fake ExpectMeta object.
    """
    failures = []
    fake_env = struct(
        ctx = real_env.ctx,
        fail = lambda msg: failures.append(msg),
        failures = failures,
    )
    meta_impl = ExpectMeta.new(fake_env)
    meta_impl_kwargs = {
        attr: getattr(meta_impl, attr)
        for attr in dir(meta_impl)
        if attr not in ("to_json", "to_proto")
    }
    fake_meta = struct(
        failures = failures,
        reset = lambda: failures.clear(),
        **meta_impl_kwargs
    )
    return fake_meta

def _expect_no_failures(env, fake_meta, case):
    """Check that a fake meta object had no failures.

    NOTE: This clears the list of failures after checking. This is done
    so that an earlier failure is only reported once.

    Args:
        env: Real `Expect` object to perform asserts.
        fake_meta: A fake meta object that had failures recorded.
        case: str, a description of the case that was tested.
    """
    env.expect.that_collection(
        fake_meta.failures,
        expr = case,
    ).contains_exactly([])
    fake_meta.reset()

def _expect_failures(env, fake_meta, case, *errors):
    """Check that a fake meta object has matching error strings.

    NOTE: This clears the list of failures after checking. This is done
    so that an earlier failure is only reported once.

    Args:
        env: Real `Expect` object to perform asserts.
        fake_meta: A fake meta object that had failures recorded.
        case: str, a description of the case that was tested.
        *errors: list of strings. These are patterns to match, as supported
            by `matching.str_matches` (e.g. `*`-style patterns)
    """
    env.expect.that_collection(
        fake_meta.failures,
        expr = case,
    ).contains_at_least_predicates(
        [matching.str_matches(e) for e in errors],
    )
    fake_meta.reset()

test_util = struct(
    fake_meta = _fake_meta,
    expect_no_failures = _expect_no_failures,
    expect_failures = _expect_failures,
)
