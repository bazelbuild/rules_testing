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

"""# Truth

Truth-style asserts for Bazel's Starlark.

These asserts follow the Truth-style way of performing assertions. This
basically means the actual value is wrapped in a type-specific object that
provides type-specific assertion methods. This style provides several benefits:
    * A fluent API that more directly expresses the assertion
    * More egonomic assert functions
    * Error messages with more informative context
    * Promotes code reuses at the type-level.

For more detailed documentation, see the docs on GitHub.

## Basic usage

NOTE: This example assumes usage of [`rules_testing`]'s [`analysis_test`]
framework, but that framework is not required.

```
def foo_test(env, target):
    subject = env.expect.that_target(target)
    subject.runfiles().contains_at_least(["foo.txt"])
    subject.executable().equals("bar.exe")

    subject = env.expect.that_action(...)
    subject.contains_at_least_args(...)
```
"""

load("//lib/private:bool_subject.bzl", "BoolSubject")
load("//lib/private:collection_subject.bzl", "CollectionSubject")
load("//lib/private:default_info_subject.bzl", "DefaultInfoSubject")
load("//lib/private:depset_file_subject.bzl", "DepsetFileSubject")
load("//lib/private:dict_subject.bzl", "DictSubject")
load("//lib/private:expect.bzl", "Expect")
load("//lib/private:file_subject.bzl", "FileSubject")
load("//lib/private:int_subject.bzl", "IntSubject")
load("//lib/private:label_subject.bzl", "LabelSubject")
load("//lib/private:runfiles_subject.bzl", "RunfilesSubject")
load("//lib/private:str_subject.bzl", "StrSubject")
load("//lib/private:target_subject.bzl", "TargetSubject")
load("//lib/private:matching.bzl", _matching = "matching")
load("//lib/private:struct_subject.bzl", "StructSubject")

# Rather than load many symbols, just load this symbol, and then all the
# asserts will be available.
truth = struct(
    expect = Expect.new_from_env,
)

# For the definition of a `Matcher` object, see `_match_custom`.
matching = _matching

subjects = struct(
    # keep sorted start
    bool = BoolSubject.new,
    collection = CollectionSubject.new,
    default_info = DefaultInfoSubject.new,
    depset_file = DepsetFileSubject.new,
    dict = DictSubject.new,
    file = FileSubject.new,
    int = IntSubject.new,
    label = LabelSubject.new,
    runfiles = RunfilesSubject.new,
    str = StrSubject.new,
    struct = StructSubject.new,
    target = TargetSubject.new,
    # keep sorted end
)
