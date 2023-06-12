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

"""# Analysis test

Support for testing analysis phase logic, such as rules.
"""

load("//lib:test_suite.bzl", _test_suite = "test_suite")
load("//lib/private:analysis_test.bzl", _analysis_test = "analysis_test")

analysis_test = _analysis_test

def test_suite(**kwargs):
    """This is an alias to lib/test_suite.bzl#test_suite.

    Args:
        **kwargs: Args passed through to test_suite
    """
    _test_suite(**kwargs)
