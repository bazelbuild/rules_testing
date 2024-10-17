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

"""Expect"""

load(":action_subject.bzl", "ActionSubject")
load(":bool_subject.bzl", "BoolSubject")
load(":collection_subject.bzl", "CollectionSubject")
load(":depset_file_subject.bzl", "DepsetFileSubject")
load(":dict_subject.bzl", "DictSubject")
load(":expect_meta.bzl", "ExpectMeta")
load(":file_subject.bzl", "FileSubject")
load(":int_subject.bzl", "IntSubject")
load(":str_subject.bzl", "StrSubject")
load(":struct_subject.bzl", "StructSubject")
load(":target_subject.bzl", "TargetSubject")

def _expect_new_from_env(env):
    """Wrapper around `env`.

    This is the entry point to the Truth-style assertions. Example usage:
        expect = expect(env)
        expect.that_action(action).contains_at_least_args(...)

    The passed in `env` object allows optional attributes to be set to
    customize behavior. Usually this is helpful for testing. See `_fake_env()`
    in truth_tests.bzl for examples.
      * `fail`: callable that takes a failure message. If present, it
        will be called instead of the regular {obj}`Expect.add_failure()` logic.
      * `get_provider`: callable that takes 2 positional args (target and
        provider) and returns the found provider or fails.
      * `has_provider`: callable that takes 2 positional args (a {obj}`Target` and
        a {obj}`provider`) and returns {obj}`bool` (`True` if present, `False`
        otherwise) or fails.

    Args:
        env: {type}`Env` unittest env struct, or some approximation. There are several
            attributes that override regular behavior; see above doc.

    Returns:
        {type}`Expect` object
    """
    return _expect_new(env, None)

def _expect_new(env, meta):
    """Creates a new Expect object.

    Internal; only other `Expect` methods should be calling this.

    Args:
        env: {type}`Env` unittest env struct or some approximation.
        meta: {type}`ExpectMeta` metadata about call chain and state.

    Returns:
        {type}`Expect` object
    """

    meta = meta or ExpectMeta.new(env)

    # buildifier: disable=uninitialized
    public = struct(
        # keep sorted start
        meta = meta,
        that_action = lambda *a, **k: _expect_that_action(self, *a, **k),
        that_bool = lambda *a, **k: _expect_that_bool(self, *a, **k),
        that_collection = lambda *a, **k: _expect_that_collection(self, *a, **k),
        that_depset_of_files = lambda *a, **k: _expect_that_depset_of_files(self, *a, **k),
        that_dict = lambda *a, **k: _expect_that_dict(self, *a, **k),
        that_file = lambda *a, **k: _expect_that_file(self, *a, **k),
        that_int = lambda *a, **k: _expect_that_int(self, *a, **k),
        that_str = lambda *a, **k: _expect_that_str(self, *a, **k),
        that_struct = lambda *a, **k: _expect_that_struct(self, *a, **k),
        that_target = lambda *a, **k: _expect_that_target(self, *a, **k),
        that_value = lambda *a, **k: _expect_that_value(self, *a, **k),
        where = lambda *a, **k: _expect_where(self, *a, **k),
        # keep sorted end
        # Attributes used by Subject classes and internal helpers
    )
    self = struct(env = env, public = public, meta = meta)
    return public

def _expect_that_action(self, action):
    """Creates a subject for asserting Actions.

    Args:
        self: implicitly added.
        action: {type}`Action` the action to check.

    Returns:
        {type}`ActionSubject` object.
    """
    return ActionSubject.new(
        action,
        self.meta.derive(
            expr = "action",
            details = ["action: [{}] {}".format(action.mnemonic, action)],
        ),
    )

def _expect_that_bool(self, value, expr = "boolean"):
    """Creates a subject for asserting a boolean.

    Args:
        self: implicitly added.
        value: {type}`bool` the bool to check.
        expr: {type}`str` the starting "value of" expression to report in errors.

    Returns:
        {type}`BoolSubject` object.
    """
    return BoolSubject.new(
        value,
        meta = self.meta.derive(expr = expr),
    )

def _expect_that_collection(self, collection, expr = "collection", **kwargs):
    """Creates a subject for asserting collections.

    Args:
        self: implicitly added.
        collection: The collection (list or depset) to assert.
        expr: {type}`str` the starting "value of" expression to report in errors.
        **kwargs: Additional kwargs to pass onto CollectionSubject.new

    Returns:
        {type}`CollectionSubject` object.
    """
    return CollectionSubject.new(collection, self.meta.derive(expr), **kwargs)

def _expect_that_depset_of_files(self, depset_files):
    """Creates a subject for asserting a depset of files.

    Method: Expect.that_depset_of_files

    Args:
        self: implicitly added.
        depset_files: {type}`depset[File]` the values to assert on.

    Returns:
        {type}`DepsetFileSubject` object.
    """
    return DepsetFileSubject.new(depset_files, self.meta.derive("depset_files"))

def _expect_that_dict(self, mapping, meta = None):
    """Creates a subject for asserting a dict.

    Method: Expect.that_dict

    Args:
        self: implicitly added
        mapping: {type}`dict` the values to assert on
        meta: {type}`ExpectMeta` optional custom call chain information to use instead

    Returns:
        {type}`DictSubject` object.
    """
    meta = meta or self.meta.derive("dict")
    return DictSubject.new(mapping, meta = meta)

def _expect_that_file(self, file, meta = None):
    """Creates a subject for asserting a file.

    Method: Expect.that_file

    Args:
        self: implicitly added.
        file: {type}`File` the value to assert.
        meta: {type}`ExpectMeta` optional custom call chain information to use instead

    Returns:
        {type}`FileSubject` object.
    """
    meta = meta or self.meta.derive("file")
    return FileSubject.new(file, meta = meta)

def _expect_that_int(self, value, expr = "integer"):
    """Creates a subject for asserting an `int`.

    Method: Expect.that_int

    Args:
        self: implicitly added.
        value: {type}`int` the value to check against.
        expr: {type}`str` the starting "value of" expression to report in errors.

    Returns:
        {type}`IntSubject` object.
    """
    return IntSubject.new(value, self.meta.derive(expr))

def _expect_that_str(self, value):
    """Creates a subject for asserting a `str`.

    Args:
        self: implicitly added.
        value: {type}`str` the value to check against.

    Returns:
        {type}`StrSubject` object.
    """
    return StrSubject.new(value, self.meta.derive("string"))

def _expect_that_struct(self, value, *, attrs, expr = "struct"):
    """Creates a subject for asserting a `struct`.

    Args:
        self: implicitly added.
        value: {type}`struct` the value to check against.
        expr: {type}`str` The starting "value of" expression to report in errors.
        attrs: {type}`dict[str, callable]` the functions to convert
            attributes to subjects. The keys are attribute names that must
            exist on `actual`. The values are functions with the signature
            `def factory(value, *, meta)`, where `value` is the actual attribute
            value of the struct, and `meta` is an {type}`ExpectMeta` object.


    Returns:
        {type}`StructSubject` object.
    """
    return StructSubject.new(value, meta = self.meta.derive(expr), attrs = attrs)

def _expect_that_target(self, target):
    """Creates a subject for asserting a `Target`.

    This adds the following parameters to `ExpectMeta.format_str`:
      {package}: The target's package, e.g. "foo/bar" from "//foo/bar:baz"
      {name}: The target's base name, e.g., "baz" from "//foo/bar:baz"

    Args:
        self: implicitly added.
        target: {obj}`Target` subject target to check against.

    Returns:
        {type}`TargetSubject` object.
    """
    return TargetSubject.new(target, self.meta.derive(
        expr = "target({})".format(target.label),
        details = ["target: {}".format(target.label)],
        format_str_kwargs = {
            "name": target.label.name,
            "package": target.label.package,
        },
    ))

def _expect_that_value(self, value, *, factory, expr = "value"):
    """Creates a subject for asserting an arbitrary value of a custom type.

    Args:
        self: implicitly added.
        value: {type}`struct` the value to check against.
        factory: A subject factory (a function that takes value and meta).
            Eg. subjects.collection
        expr: {type}`str` The starting "value of" expression to report in errors.

    Returns:
        A subject corresponding to the type returned by the factory.
    """
    return factory(value, meta = self.meta.derive(expr))

def _expect_where(self, **details):
    """Add additional information about the assertion.

    This is useful for attaching information that isn't part of the call
    chain or some reason. Example usage:

        expect(env).where(platform=ctx.attr.platform).that_str(...)

    Would include "platform: {ctx.attr.platform}" in failure messages.

    Args:
        self: implicitly added.
        **details: {type}`dict[str, value]` Each named arg is added to
            the metadata details with the provided string, which is printed as
            part of displaying any failures.

    Returns:
        {type}`Expect` object with separate metadata derived from the original self.
    """
    meta = self.meta.derive(
        details = ["{}: {}".format(k, v) for k, v in details.items()],
    )
    return _expect_new(env = self.env, meta = meta)

def _expect_typedef():
    """Entry point for truth-style assertions with context.

    This is typically created through `env.expect` as part of the
    analysis test framework. It holds context related to the test
    state for later use in asserts and error reporting.
    """

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
Expect = struct(
    TYPEDEF = _expect_typedef,
    # keep sorted start
    new = _expect_new,
    new_from_env = _expect_new_from_env,
    that_action = _expect_that_action,
    that_bool = _expect_that_bool,
    that_collection = _expect_that_collection,
    that_depset_of_files = _expect_that_depset_of_files,
    that_dict = _expect_that_dict,
    that_file = _expect_that_file,
    that_int = _expect_that_int,
    that_str = _expect_that_str,
    that_struct = _expect_that_struct,
    that_target = _expect_that_target,
    that_value = _expect_that_value,
    where = _expect_where,
    # keep sorted end
)
