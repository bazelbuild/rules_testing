# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""# Unit test

Support for testing generic Starlark code, i.e. code that doesn't require
the analysis phase or instantiate rules.
"""

# We have to load the private impl to avoid a circular dependency
load("//lib/private:analysis_test.bzl", "analysis_test")

_TARGET = Label("//lib:_stub_target_for_unit_tests")

def unit_test(name, impl, attrs = {}):
    """Creates a test for generic Starlark code (i.e. non-rule/macro specific).

    Unless you need custom attributes passed to the test, you probably don't need
    this and can, instead, pass your test function directly to `test_suite.tests`.

    See also: analysis_test, for testing analysis time behavior, such as rules.

    Args:
        name: (str) the name of the test
        impl: (callable) the function implementing the test's asserts. It takes
            a single position arg, `env`, which is information about the
            test environment (see analysis_test docs).
        attrs: (dict of str to str) additional attributes to make available to
            the test.
    """
    analysis_test(
        name = name,
        impl = lambda env, target: impl(env),
        target = _TARGET,
        attrs = attrs,
    )
