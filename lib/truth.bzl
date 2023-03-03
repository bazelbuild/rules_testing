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

"""Various asserts to aid with testing.

These asserts follow the Truth-style way of performing assertions. This
basically means the actual value is wrapped in a type-specific object that
provides type-specific assertion methods. This style provides several benefits:
    * A fluent API that more directly expresses the assertion
    * More egonomic assert functions
    * Error messages with more informative context
    * Promotes code reuses at the type-level.

## Example Usage:

```
def foo_test(env, target, actions):
    subject = env.expect.that_target(target)
    subject.runfiles().contains_at_least(["foo.txt"])
    subject.executable().equals("bar.exe")

    subject = env.expect.that_action(...)
    subject.contains_at_least_args(...)
```

## Writing a new Subject

Writing a new Subject involves two basic pieces:

    1. Creating a constructor function, e.g. `_foo_subject_new`, that takes
       the actual value and an `ExpectMeta` object (see `_expect_meta_new()`).

    2. Adding a method to `expect` or another Subject class to
       pass along state and instantiate the new subject; both may be modified if
       the actual object can be independenly created or obtained through another
       subject.

       For top-level subjects, a method named `that_foo()` should be added
       to the `expect` class.

       For child-subjects, an appropriately named method should be added to
       the parent subject, and the parent subject should call `ExpectMeta.derive()`
       to create a new set of meta data for the child subject.

The assert methods a subject provides are up to the subject, but try to follow
the naming scheme of other subjects. The purpose of a custom subject is to make
it easier to write tests that are correct and informative. It's common to have a
combination of ergonomic asserts for common cases, and delegating to
child-subjects for other cases.


## Adding asserts to a subject

Fundamentally, an assert method calls `ExpectMeta.add_failure()` to record
when there is a failure. That method will wire together any surrounding context
with the provided error message information. Otherwise an assertion is free
to implement checks how it pleases.

The naming of functions should mostly read naturally, but doesn't need to be
perfect grammatically. Be aware of ambiguous words like "contains" or
"matches". For example, `contains_flag("--foo")` -- does this check that
"--flag" was specified at all (ignoring value), or that it was specified and
has no value?

Assertion functions can make use of a variety of helper methods in
processing values, comparing them, and generating error messages. Helpers
of particular note are:

    * `_check_*`: These functions implement comparison, error formatting, and
      error reporting.
    * `_compare_*`: These functions implements comparison for different cases
      and take care of various edge cases.
    * `_format_failure_*`: These functions create human-friendly messages
      describing both the observed values and the problem with them.
    * `_format_problem_*`: These functions format only the problem identified.
    * `_format_actual_*`: These functions format only the observed values.
"""

load("@bazel_skylib//lib:types.bzl", "types")
load("@bazel_skylib//lib:unittest.bzl", ut_asserts = "asserts")
load(
    ":util.bzl",
    "TestingAspectInfo",
    "is_file",
    "is_runfiles",
    "runfiles_paths",
)

def _mkmethod(self, method):
    """Bind a struct as the first arg to a function.

    This is loosely equivalent to creating a bound method of a class.
    """
    return lambda *args, **kwargs: method(self, *args, **kwargs)

def _expect(env):
    """Wrapper around `env`.

    This is the entry point to the Truth-style assertions. Example usage:
        expect = expect(env)
        expect.that_action(action).contains_at_least_args(...)

    The passed in `env` object allows optional attributes to be set to
    customize behavior. Usually this is helpful for testing. See `_fake_env()`
    in truth_tests.bzl for examples.
      * fail: callable that takes a failure message. If present, it
        will be called instead of the regular `Except.add_failure` logic.
      * get_provider: callable that takes 2 positional args (target and
        provider) and returns the found provider or fails.
      * has_provider: callable that takes 2 positional args (target and
        provider) and returns bool (true if present) or fails.

    Args:
        env: unittest env struct, or some approximation. There are several
            attributes that override regular behavior; see above doc.

    Returns:
        A struct representing an "expect object".
    """
    return _expect_new(env, None)

def _expect_new(env, meta):
    """Creates a new Expect object.

    Internal; only other `Expect` methods should be calling this.

    Args:
        env: unittest env struct or some approximation.
        meta: ExpectMeta; metadata about call chain and state.

    Returns:
        A struct representing an `Expect` object.
    """

    meta = meta or _expect_meta_new(env)

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
        that_target = lambda *a, **k: _expect_that_target(self, *a, **k),
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
        action: The `Action` to check.

    Returns:
        A struct representing an "ActionSubject" (see `_action_subject_new`)
    """
    return _action_subject_new(
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
        value: bool; the bool to check.
        expr: str; the starting "value of" expression to report in errors.
    Returns:
        A `BoolSubject` (see `_bool_subject_new`).
    """
    return _bool_subject_new(
        value,
        meta = self.meta.derive(expr = expr),
    )

def _expect_that_collection(self, collection, expr = "collection"):
    """Creates a subject for asserting collections.

    Args:
        self: implicitly added.
        collection: The collection (list or depset) to assert.
        expr: str; the starting "value of" expression to report in errors.

    Returns:
        A struct representing an "CollectionSubject" (see `_collection_subject_new`)
    """
    return _collection_subject_new(collection, self.meta.derive(expr))

def _expect_that_depset_of_files(self, depset_files):
    """Creates a subject for asserting a depset of files.

    Method: Expect.that_depset_of_files

    Args:
        self: implicitly added.
        depset_files: The depset of files to assert.

    Returns:
        A struct representing an "DepsetFileSubject" (see `_depset_file_new`)
    """
    return _depset_file_subject_new(depset_files, self.meta.derive("depset_files"))

def _expect_that_dict(self, mapping, meta = None):
    """Creates a subject for asserting a dict.

    Method: Expect.that_dict

    Args:
        self: implicitly added
        mapping: dict; the values to assert on
        meta: ExpectMeta; optional custom call chain information to use instead

    Returns:
        A `DictSubject` (see `_dict_subject_new`).
    """
    meta = meta or self.meta.derive("dict")
    return _dict_subject_new(mapping, meta = meta)

def _expect_that_file(self, file, meta = None):
    """Creates a subject for asserting a file.

    Method: Expect.that_file

    Args:
        self: implicitly added.
        file: The file to assert.
        meta: ExpectMeta; optional custom call chain information to use instead

    Returns:
        A `FileSubject` struct (see `_file_subject_new`)
    """
    meta = meta or self.meta.derive("file")
    return _file_subject_new(file, meta = meta)

def _expect_that_int(self, value, expr = "integer"):
    """Creates a subject for asserting an `int`.

    Method: Expect.that_int

    Args:
        self: implicitly added.
        value: int; the value to check against.
        expr: str; the starting "value of" expression to report in errors.
    Returns:
        A struct representing an "IntSubject" (see `_int_subject_new`).
    """
    return _int_subject_new(value, self.meta.derive(expr))

def _expect_that_str(self, value):
    """Creates a subject for asserting a `str`.

    Args:
        self: implicitly added.
        value: str; the value to check against.
    Returns:
        A struct representing an "StrSubject" (see `_str_subject_new`).
    """
    return _str_subject_new(value, self.meta.derive("string"))

def _expect_that_target(self, target):
    """Creates a subject for asserting a `Target`.

    This adds the following parameters to `ExpectMeta.format_str`:
      {package}: The target's package, e.g. "foo/bar" from "//foo/bar:baz"
      {name}: The target's base name, e.g., "baz" from "//foo/bar:baz"

    Args:
        self: implicitly added.
        target: Target; subject target to check against.

    Returns:
        A struct representing a "TargetSubject" (see `_target_subject_new`).
    """
    return _target_subject_new(target, self.meta.derive(
        expr = "target({})".format(target.label),
        details = ["target: {}".format(target.label)],
        format_str_kwargs = {
            "name": target.label.name,
            "package": target.label.package,
        },
    ))

def _expect_where(self, **details):
    """Add additional information about the assertion.

    This is useful for attaching information that isn't part of the call
    chain or some reason. Example usage:

        expect(env).where(platform=ctx.attr.platform).that_str(...)

    Would include "platform: {ctx.attr.platform}" in failure messages.

    Args:
        self: implicitly added.
        **details: str; Each named arg is added to the metadata details
            with the provided string, which is printed as part of displaying
            any failures.
    Returns:
        `Expect` object with separate metadata derived from the original self.
    """
    meta = self.meta.derive(
        details = ["{}: {}".format(k, v) for k, v in details.items()],
    )
    return _expect_new(env = self.env, meta = meta)

def _expect_meta_new(env, exprs = [], details = [], format_str_kwargs = None):
    """Creates a new "ExpectMeta" struct".

    Method: ExpectMeta.new

    ExpectMeta objects are internal helpers for the Expect object and Subject
    objects. They are used for Subjects to store and communicate state through a
    series of call chains and asserts.

    This constructor should only be directly called by `Expect` objects. When a
    parent Subject is creating a child-Subject, then `meta.derive()` should be
    used.

    Env objects

    The `env` object basically provides a way to interact with things outside
    of the truth assertions framework. This allows easier testing of the
    framework itself and decouples it from a particular test framework (which
    makes it usuable by by rules_testing's analysis_test and skylib's
    analysistest)

    The `env` object requires the following attribute:
      * ctx: The test's ctx.

    The `env` object allows the following attributes to customize behavior:
      * fail: A callable that accepts a single string, which is the failure
        message. Its return value is ignored. This is called when an assertion
        fails. It's generally expected that it records a failure instead of
        immediately failing.
      * has_provider: A callable; it accepts two positional args, target and
        provider and returns boolean. This is used to implement `Provider in
        target` operations.
      * get_provider: A callable; it accepts two positional args, target and
        provider and returns the provder value. This is used to implement
        `target[Provider]`.

    Args:
        env: unittest env struct or some approximation.
        exprs: list of str; the expression strings of the call chain for
            the subject.
        details: list of str; additional details to print on error. These
            are usually informative details of the objects under test.
        format_str_kwargs: optional dict of format() kwargs. These kwargs
            are propagated through `derive()` calls and used when
            `ExpectMeta.format_str()` is called.

    Returns:
        A struct representing an "ExpectMeta" object.
    """
    if format_str_kwargs == None:
        format_str_kwargs = {}
    format_str_kwargs.setdefault("workspace", env.ctx.workspace_name)
    format_str_kwargs.setdefault("test_name", env.ctx.label.name)

    # buildifier: disable=uninitialized
    self = struct(
        ctx = env.ctx,
        env = env,
        add_failure = lambda *a, **k: _expect_meta_add_failure(self, *a, **k),
        derive = lambda *a, **k: _expect_meta_derive(self, *a, **k),
        format_str = lambda *a, **k: _expect_meta_format_str(self, *a, **k),
        get_provider = lambda *a, **k: _expect_meta_get_provider(self, *a, **k),
        has_provider = lambda *a, **k: _expect_meta_has_provider(self, *a, **k),
        _exprs = exprs,
        _details = details,
        _format_str_kwargs = format_str_kwargs,
    )
    return self

def _expect_meta_derive(self, expr = None, details = None, format_str_kwargs = {}):
    """Create a derivation of the current meta object for a child-Subject.

    Method: ExpectMeta.derive

    When a Subject needs to create a child-Subject, it derives a new meta
    object to pass to the child. This separates the parent's state from
    the child's state and allows any failures generated by the child to
    include the context of the parent creator.

    Example usage:
        def _foo_subject_action_named(self, name):
            meta = self.meta.derive("action_named({})".format(name),
                                    "action: {}".format(...))
            return ActionSubject(..., meta)
        def _foo_subject_name(self):
            # No extra detail to include)
            meta self.meta.derive("name()", None)


    Args:
        self: implicitly added.
        expr: str; human-friendly description of the call chain expression.
            e.g., if `foo_subject.bar_named("baz")` returns a child-subject,
            then "bar_named("bar")" would be the expression.
        details: optional list of str; human-friendly descriptions of additional
            detail to include in errors. This is usually additional information
            the child Subject wouldn't include itself. e.g. if
            `foo.first_action_argv().contains(1)`, returned a ListSubject, then
            including "first action: Action FooCompile" helps add context to the
            error message. If there is no additional detail to include, pass
            None.
        format_str_kwargs: dict of format()-kwargs; additional kwargs to
            make available to `ExpectMeta.format_str` calls.

    Returns:
        A new ExpectMeta struct.
    """
    if not details:
        details = []
    if expr:
        exprs = [expr]
    else:
        exprs = []

    if format_str_kwargs:
        final_format_kwargs = {k: v for k, v in self._format_str_kwargs.items()}
        final_format_kwargs.update(format_str_kwargs)
    else:
        final_format_kwargs = self._format_str_kwargs

    return _expect_meta_new(
        env = self.env,
        exprs = self._exprs + exprs,
        details = self._details + details,
        format_str_kwargs = final_format_kwargs,
    )

def _expect_meta_format_str(self, template):
    """Interpolate contextual keywords into a string.

    This uses the normal `format()` style (i.e. using `{}`). Keywords
    refer to parts of the call chain.

    The particular keywords supported depend on the call chain. The following
    are always present:
      {workspace}: The name of the workspace, e.g. "rules_proto".
      {test_name}: The base name of the current test.

    Args:
        self: implicitly added.
        template: str; the format template string to use.

    Returns:
        str; the template with parameters replaced.
    """
    return template.format(**self._format_str_kwargs)

def _expect_meta_get_provider(self, target, provider):
    """Get a provider from a target.

    This is equivalent to `target[provider]`; the extra level of indirection
    is to aid testing.

    Args:
        self: implicitly added.
        target: Target; the target to get the provider from.
        provider: The provider type to get.
    Returns:
        The found provider, or fails if not present.
    """
    if hasattr(self.env, "get_provider"):
        return self.env.get_provider(target, provider)
    else:
        return target[provider]

def _expect_meta_has_provider(self, target, provider):
    """Tells if a target has a provider.

    This is equivalent to `provider in target`; the extra level of indirection
    is to aid testing.

    Args:
        self: implicitly added.
        target: Target; the target to check for the provider.
        provider: the provider type to check for.
    Returns:
        True if the target has the provider, False if not.
    """
    if hasattr(self.env, "has_provider"):
        return self.env.has_provider(target, provider)
    else:
        return provider in target

def _expect_meta_add_failure(self, problem, actual):
    """Adds a failure with context.

    Method: ExpectMeta.add_failure

    Adds the given error message. Context from the subject and prior call chains
    is automatically added.

    Args:
        self: implicitly added.
        problem: str; a string describing the expected value or problem
            detected, and the expected values that weren't satisfied. A colon
            should be used to separate the description from the values.
            The description should be brief and include the word "expected",
            e.g. "expected: foo", or "expected values missing: <list of missing>",
            the key point being the reader can easily take the values shown
            and look for it in the actual values displayed below it.
        actual: str; a string describing the values observed. A colon should
            be used to separate the description from the observed values.
            The description should be brief and include the word "actual", e.g.,
            "actual: bar". The values should include the actual, observed,
            values and pertinent information about them.
    """
    details = "\n".join([
        "  {}".format(detail)
        for detail in self._details
        if detail
    ])
    if details:
        details = "where...\n" + details
    msg = """\
in test: {test}
value of: {expr}
{problem}
{actual}
{details}
""".format(
        test = self.ctx.label,
        expr = ".".join(self._exprs),
        problem = problem,
        actual = actual,
        details = details,
    )
    _expect_meta_call_fail(self, msg)

def _expect_meta_call_fail(self, msg):
    """Adds a failure to the test run.

    Args:
        self: implicitly added.
        msg: str; the failure message.
    """
    fail_func = getattr(self.env, "fail", None)
    if fail_func != None:
        fail_func(msg)
    else:
        # Add a leading newline because unittest prepends the repr() of the
        # function under test, which is often long and uninformative, making
        # the first line of our message hard to see.
        ut_asserts.true(self.env, False, "\n" + msg)

def _action_subject_new(action, meta):
    """Creates an "ActionSubject" struct.

    Method: ActionSubject.new

    Example usage:
        expect(env).that_action(action).not_contains_arg("foo")

    Args:
        action: Action to check against.
        meta: `ExpectMeta` struct of call chain information.

    Returns:
        A struct representing an "ActionSubject". See the `public` struct
        in the source for the available methods.
    """

    # buildifier: disable=uninitialized
    self = struct(
        action = action,
        meta = meta,
        # Dict[str, list[str]] of flags. The keys must be in the same order
        # as found in argv to allow ordering asserts of them.
        parsed_flags = _action_subject_parse_flags(action.argv),
    )
    public = struct(
        # keep sorted start
        actual = action,
        argv = _mkmethod(self, _action_subject_argv),
        contains_at_least_args = _mkmethod(self, _action_subject_contains_at_least_args),
        contains_at_least_inputs = _mkmethod(self, _action_subject_contains_at_least_inputs),
        contains_flag_values = _mkmethod(self, _action_subject_contains_flag_values),
        contains_none_of_flag_values = _mkmethod(self, _action_subject_contains_none_of_flag_values),
        content = _mkmethod(self, _action_subject_content),
        env = _mkmethod(self, _action_subject_env),
        has_flags_specified = _mkmethod(self, _action_subject_has_flags_specified),
        inputs = _mkmethod(self, _action_subject_inputs),
        mnemonic = _mkmethod(self, _action_subject_mnemonic),
        not_contains_arg = _mkmethod(self, _action_subject_not_contains_arg),
        substitutions = _mkmethod(self, _action_subject_substitutions),
        # keep sorted end
    )
    return public

def _action_subject_parse_flags(argv):
    parsed_flags = {}

    # argv might be none for e.g. builtin actions
    if argv == None:
        return parsed_flags
    for i, arg in enumerate(argv):
        if not arg.startswith("--"):
            continue
        if "=" in arg:
            name, value = arg.split("=", 1)
        else:
            name = arg

            # Handle a flag being the last arg in argv
            if (i + 1) < len(argv):
                value = argv[i + 1]
            else:
                value = None
        parsed_flags.setdefault(name, []).append(value)
    return parsed_flags

def _action_subject_argv(self):
    """Returns a CollectionSubject for the action's argv.

    Method: ActionSubject.argv
    """
    meta = self.meta.derive("argv()")
    return _collection_subject_new(
        self.action.argv,
        meta,
        container_name = "argv",
        sortable = False,
    )

def _action_subject_contains_at_least_args(self, args):
    """Assert that an action contains at least the provided args.

    Method: ActionSubject.contains_at_least_args

    Example usage:
        expect(env).that_action(action).contains_at_least_args(["foo", "bar"]).

    Args:
        self: implicitly added.
        args: list of strings; all the args must be in the argv exactly
            as provided. Multiplicity is respected.
    Returns
        an `Ordered` struct (see `_ordered_incorrectly_new`).
    """
    return _collection_subject_new(
        self.action.argv,
        self.meta,
        container_name = "argv",
        element_plural_name = "args",
        sortable = False,  # Preserve argv ordering
    ).contains_at_least(args)

def _action_subject_not_contains_arg(self, arg):
    """Assert that an action does not contain an arg.

    Example usage:
        expect(env).that_action(action).not_contains_arg("should-not-exist")

    Args:
        self: implicitly added.
        arg: str; the arg that cannot be present in the argv.
    """
    if arg in self.action.argv:
        problem, actual = _format_failure_unexpected_value(
            container_name = "argv",
            unexpected = arg,
            actual = self.action.argv,
            sort = False,  # Preserve argv ordering
        )
        self.meta.add_failure(problem, actual)

def _action_subject_substitutions(self):
    """Creates a `DictSubject` to assert on the substitutions dict.

    Method: ActionSubject.substitutions.

    Args:
        self: implicitly added

    Returns:
        `DictSubject` struct.
    """
    return _dict_subject_new(
        actual = self.action.substitutions,
        meta = self.meta.derive("substitutions()"),
    )

def _action_subject_has_flags_specified(self, flags):
    """Assert that an action has the given flags present (but ignore any value).

    Method: ActionSubject.has_flags_specified

    This parses the argv, assuming the typical formats (`--flag=value`,
    `--flag value`, and `--flag`). Any of the formats will be matched.

    Example usage, given `argv = ["--a", "--b=1", "--c", "2"]`:
        expect(env).that_action(action).has_flags_specified([
            "--a", "--b", "--c"])

    Args:
        self: implicitly added.
        flags: list of str; The flags to check for. Include the leading "--".
            Multiplicity is respected. A flag is considered present if any of
            these forms are detected: `--flag=value`, `--flag value`, or a lone
            `--flag`.
    Returns
        an `Ordered` struct (see `_ordered_incorrectly_new`).
    """
    return _collection_subject_new(
        # Starlark dict keys maintain insertion order, so it's OK to
        # pass keys directly and return Ordered.
        self.parsed_flags.keys(),
        meta = self.meta,
        container_name = "argv",
        element_plural_name = "specified flags",
        sortable = False,  # Preserve argv ordering
    ).contains_at_least(flags)

def _action_subject_mnemonic(self):
    """Returns a `StrSubject` for the action's mnemonic.

    Method: ActionSubject.mnemonic
    """
    return _str_subject_new(
        self.action.mnemonic,
        meta = self.meta.derive("mnemonic()"),
    )

def _action_subject_inputs(self):
    """Returns a DepsetFileSubject for the action's inputs.

    Method: ActionSubject.inputs

    Returns:
        `DepsetFileSubject` of the action's inputs.
    """
    meta = self.meta.derive("inputs()")
    return _depset_file_subject_new(self.action.inputs, meta)

def _action_subject_contains_flag_values(self, flag_values):
    """Assert that an action's argv has the given ("--flag", "value") entries.

    Method: ActionSubject.contains_flag_values

    This parses the argv, assuming the typical formats (`--flag=value`,
    `--flag value`, and `--flag`). Note, however, that for the `--flag value`
    and `--flag` forms, the parsing can't know how many args, if any, a flag
    actually consumes, so it simply takes the first following arg, if any, as
    the matching value.

    NOTE: This function can give misleading results checking flags that don't
    consume any args (e.g. boolean flags). Use `has_flags_specified()` to test
    for such flags. Such cases will either show the subsequent arg as the value,
    or None if the flag was the last arg in argv.

    Example usage, given `argv = ["--b=1", "--c", "2"]`:
        expect(env).that_action(action).contains_flag_values([
            ("--b", "1"),
            ("--c", "2")
        ])

    Args:
        self: implicitly added.
        flag_values: list of (str name, str value) pairs. Include the leading "--"
            in the flag name. Order and duplicates aren't checked. Flags without
            a value found use `None` as their value.
    """
    missing = []
    for flag, value in sorted(flag_values):
        if flag not in self.parsed_flags:
            missing.append("'{}' (not specified)".format(flag))
        elif value not in self.parsed_flags[flag]:
            missing.append("'{}' with value '{}'".format(flag, value))
    if not missing:
        return
    problem, actual = _format_failure_missing_all_values(
        element_plural_name = "flags with values",
        container_name = "argv",
        missing = missing,
        actual = self.action.argv,
        sort = False,  # Preserve argv ordering
    )
    self.meta.add_failure(problem, actual)

def _action_subject_contains_none_of_flag_values(self, flag_values):
    """Assert that an action's argv has none of the given ("--flag", "value") entries.

    Method: ActionSubject.contains_none_of_flag_values

    This parses the argv, assuming the typical formats (`--flag=value`,
    `--flag value`, and `--flag`). Note, however, that for the `--flag value`
    and `--flag` forms, the parsing can't know how many args, if any, a flag
    actually consumes, so it simply takes the first following arg, if any, as
    the matching value.

    NOTE: This function can give misleading results checking flags that don't
    consume any args (e.g. boolean flags). Use `has_flags_specified()` to test
    for such flags.

    Args:
        self: implicitly added.
        flag_values: list of (str name, str value) pairs. Include the leading
            "--" in the flag name. Order and duplicates aren't checked.
    """
    unexpected = []
    for flag, value in sorted(flag_values):
        if flag not in self.parsed_flags:
            continue
        elif value in self.parsed_flags[flag]:
            unexpected.append("'{}' with value '{}'".format(flag, value))
    if not unexpected:
        return

    problem, actual = _format_failure_unexpected_values(
        none_of = "\n" + _enumerate_list_as_lines(sorted(unexpected), prefix = "  "),
        unexpected = unexpected,
        actual = self.action.argv,
        sort = False,  # Preserve argv ordering
    )
    self.meta.add_failure(problem, actual)

def _action_subject_contains_at_least_inputs(self, inputs):
    """Assert the action's inputs contains at least all of `inputs`.

    Method: ActionSubject.contains_at_least_inputs

    Example usage:
        expect(env).that_action(action).contains_at_least_inputs([<some file>])

    Args:
        self: implicitly added.
        inputs: a collection of File's. All must be present. Multiplicity
            is respected.
    Returns
        an `Ordered` struct (see `_ordered_incorrectly_new`).
    """
    return _depset_file_subject_new(
        self.action.inputs,
        meta = self.meta,
        container_name = "action inputs",
        element_plural_name = "inputs",
    ).contains_at_least(inputs)

def _action_subject_content(self):
    """Returns a `StrSubject` for `Action.content`.

    Method: ActionSubject.content
    """
    return _str_subject_new(
        self.action.content,
        self.meta.derive("content()"),
    )

def _action_subject_env(self):
    """Returns a `DictSubject` for `Action.env`.

    Method: ActionSubject.env

    Args:
        self: implicitly added.
    """
    return _dict_subject_new(
        self.action.env,
        self.meta.derive("env()"),
        container_name = "environment",
        key_plural_name = "envvars",
    )

def _bool_subject_new(value, meta):
    """Creates a "BoolSubject" struct.

    Method: BoolSubject.new

    Args:
        value: bool; the value to assert against.
        meta: `Expectmeta` struct; the metadata about the call chain.
    Returns:
        A "BoolSubject" struct.
    """
    self = struct(actual = value, meta = meta)
    public = struct(
        # keep sorted start
        equals = lambda *a, **k: _bool_subject_equals(self, *a, **k),
        is_in = lambda *a, **k: _common_subject_is_in(self, *a, **k),
        not_equals = lambda *a, **k: _bool_subject_not_equals(self, *a, **k),
        # keep sorted end
    )
    return public

def _bool_subject_equals(self, expected):
    """Assert that the bool is equal to `expected`.

    Method: BoolSubject.equals

    Args:
        self: implicitly added.
        expected: bool; the expected value.
    """
    if self.actual == expected:
        return
    self.meta.add_failure(
        "expected: {}".format(expected),
        "actual: {}".format(self.actual),
    )

def _bool_subject_not_equals(self, unexpected):
    """Assert that the bool is not equal to `unexpected`.

    Method: BoolSubject.not_equals

    Args:
        self: implicitly added.
        unexpected: bool; the value actual cannot equal.
    """
    return _check_not_equals(
        actual = self.actual,
        unexpected = unexpected,
        meta = self.meta,
    )

def _collection_subject_new(
        values,
        meta,
        container_name = "values",
        sortable = True,
        element_plural_name = "elements"):
    """Creates a "CollectionSubject" struct.

    Method: CollectionSubject.new

    Args:
        values: collection; the values to assert against.
        meta: `ExpectMeta` struct; the metadata about the call chain.
        container_name: str; conceptual name of the container.
        sortable: bool; True if output should be sorted for display, false if not.
        element_plural_name: str; the plural word for the values in the container.
    Returns:
        A struct representing a "CollectionSubject".
    """

    # buildifier: disable=uninitialized
    public = struct(
        # keep sorted start
        actual = values,
        has_size = lambda *a, **k: _collection_subject_has_size(self, *a, **k),
        contains = lambda *a, **k: _collection_subject_contains(self, *a, **k),
        contains_at_least = lambda *a, **k: _collection_subject_contains_at_least(self, *a, **k),
        contains_at_least_predicates = lambda *a, **k: _collection_subject_contains_at_least_predicates(self, *a, **k),
        contains_exactly = lambda *a, **k: _collection_subject_contains_exactly(self, *a, **k),
        contains_exactly_predicates = lambda *a, **k: _collection_subject_contains_exactly_predicates(self, *a, **k),
        contains_none_of = lambda *a, **k: _collection_subject_contains_none_of(self, *a, **k),
        contains_predicate = lambda *a, **k: _collection_subject_contains_predicate(self, *a, **k),
        not_contains_predicate = lambda *a, **k: _collection_subject_not_contains_predicate(self, *a, **k),
        # keep sorted end
    )
    self = struct(
        actual = values,
        meta = meta,
        element_plural_name = element_plural_name,
        container_name = container_name,
        sortable = sortable,
        contains_predicate = public.contains_predicate,
        contains_at_least_predicates = public.contains_at_least_predicates,
    )
    return public

def _collection_subject_has_size(self, expected):
    """Asserts that `expected` is the size of the collection.

    Method: CollectionSubject.has_size

    Args:
        self: implicitly added.
        expected: int; the expected size of the collection.
    """
    return _int_subject_new(
        len(self.actual),
        meta = self.meta.derive("size()"),
    ).equals(expected)

def _collection_subject_contains(self, expected):
    """Asserts that `expected` is within the collection.

    Method: CollectionSubject.contains

    Args:
        self: implicitly added.
        expected: str; the value that must be present.
    """
    matcher = matching.equals_wrapper(expected)
    return self.contains_predicate(matcher)

def _collection_subject_contains_exactly(self, expected):
    """Check that a collection contains exactly the given elements.

    Method: CollectionSubject.contains_exactly

    * Multiplicity is respected.
    * The collection must contain all the values, no more or less.
    * Checking that the order of matches is the same as the passed-in matchers
      order can be done by call `in_order()`.

    The collection must contain all the values and no more. Multiplicity of
    values is respected. Checking that the order of matches is the same as the
    passed-in matchers order can done by calling `in_order()`.

    Args:
        self: implicitly added.
        expected: list of values that must exist.
    Returns
        an `Ordered` struct (see `_ordered_incorrectly_new`).
    """
    expected = _to_list(expected)
    return _check_contains_exactly(
        actual_container = self.actual,
        expect_contains = expected,
        meta = self.meta,
        format_actual = lambda: _format_actual_collection(
            self.actual,
            name = self.container_name,
            sort = False,  # Don't sort; this might be rendered by the in_order() error.
        ),
        format_expected = lambda: _format_problem_expected_exactly(
            expected,
            sort = False,  # Don't sort; this might be rendered by the in_order() error.
        ),
        format_missing = lambda missing: _format_problem_missing_required_values(
            missing,
            sort = self.sortable,
        ),
        format_unexpected = lambda unexpected: _format_problem_unexpected_values(
            unexpected,
            sort = self.sortable,
        ),
        format_out_of_order = _format_problem_matched_out_of_order,
    )

def _collection_subject_contains_exactly_predicates(self, expected):
    """Check that the values correspond 1:1 to the predicates.

    Method: CollectionSubject.contains_exactly_predicates

    * There must be a 1:1 correspondence between the container values and the
      predicates.
    * Multiplicity is respected (i.e., if the same predicate occurs twice, then
      two distinct elements must match).
    * Matching occurs in first-seen order. That is, a predicate will "consume"
      the first value in `actual_container` it matches.
    * The collection must match all the predicates, no more or less.
    * Checking that the order of matches is the same as the passed-in matchers
      order can be done by call `in_order()`.

    Note that confusing results may occur if predicates with overlapping
    match conditions are used. For example, given:
      actual=["a", "ab", "abc"],
      predicates=[<contains a>, <contains b>, <equals a>]

    Then the result will be they aren't equal: the first two predicates
    consume "a" and "ab", leaving only "abc" for the <equals a> predicate
    to match against, which fails.

    Args:
        self: implicitly added.
        expected: list of predicates that must match.
    Returns
        an `Ordered` struct (see `_ordered_incorrectly_new`).
    """
    expected = _to_list(expected)
    return _check_contains_exactly_predicates(
        actual_container = self.actual,
        expect_contains = expected,
        meta = self.meta,
        format_actual = lambda: _format_actual_collection(
            self.actual,
            name = self.container_name,
            sort = False,  # Don't sort; this might be rendered by the in_order() error.
        ),
        format_expected = lambda: _format_problem_expected_exactly(
            [e.desc for e in expected],
            sort = False,  # Don't sort; this might be rendered by the in_order() error.
        ),
        format_missing = lambda missing: _format_problem_missing_required_values(
            [m.desc for m in missing],
            sort = self.sortable,
        ),
        format_unexpected = lambda unexpected: _format_problem_unexpected_values(
            unexpected,
            sort = self.sortable,
        ),
        format_out_of_order = _format_problem_matched_out_of_order,
    )

def _collection_subject_contains_none_of(self, values):
    """Asserts the collection contains none of `values`.

    Method: CollectionSubject.contains_none_of

    Args:
        self: implicitly added
        values: collection of values, none of which are allowed to exist.
    """
    _check_contains_none_of(
        collection = self.actual,
        none_of = values,
        meta = self.meta,
        sort = self.sortable,
    )

def _collection_subject_contains_predicate(self, matcher):
    """Asserts that `matcher` matches at least one value.

    Method: CollectionSubject.contains_predicate

    Args:
        self: implicitly added.
        matcher: `Matcher` object (see `matchers` struct).
    """
    _check_contains_predicate(
        self.actual,
        matcher = matcher,
        format_problem = "expected to contain: {}".format(matcher.desc),
        format_actual = lambda: _format_actual_collection(
            self.actual,
            name = self.container_name,
            sort = self.sortable,
        ),
        meta = self.meta,
    )

def _collection_subject_contains_at_least(self, expect_contains):
    """Assert that the collection is a subset of the given predicates.

    Method: CollectionSubject.contains_at_least

    The collection must contain all the values. It can contain extra elements.
    The multiplicity of values is respected. Checking that the relative order
    of matches is the same as the passed-in expected values order can done by
    calling `in_order()`.

    Args:
        self: implicitly added.
        expect_contains: list of values that must be in the collection

    Returns:
        an `Ordered` struct (see `_ordered_incorrectly_new`).
    """
    matchers = [
        matching.equals_wrapper(expected)
        for expected in _to_list(expect_contains)
    ]
    return self.contains_at_least_predicates(matchers)

def _collection_subject_contains_at_least_predicates(self, matchers):
    """Assert that the collection is a subset of the given predicates.

    Method: CollectionSubject.contains_at_least_predicates

    The collection must match all the predicates. It can contain extra elements.
    The multiplicity of matchers is respected. Checking that the relative order
    of matches is the same as the passed-in matchers order can done by calling
    `in_order()`.

    Args:
        self: implicitly added.
        matchers: list of `Matcher` objects (see `matchers` struct).

    Returns:
        an `Ordered` struct (see `_ordered_incorrectly_new`).
    """
    ordered = _check_contains_at_least_predicates(
        self.actual,
        matchers,
        format_missing = lambda missing: _format_problem_predicates_did_not_match(
            missing,
            element_plural_name = self.element_plural_name,
            container_name = self.container_name,
        ),
        format_out_of_order = _format_problem_matched_out_of_order,
        format_actual = lambda: _format_actual_collection(
            self.actual,
            name = self.container_name,
            sort = self.sortable,
        ),
        meta = self.meta,
    )
    return ordered

def _collection_subject_not_contains_predicate(self, matcher):
    """Asserts that `matcher` matches no values in the collection.

    Method: CollectionSubject.not_contains_predicate

    Args:
        self: implicitly added.
        matcher: `Matcher` object (see `matchers` struct).
    """
    _check_not_contains_predicate(
        self.actual,
        matcher = matcher,
        meta = self.meta,
        sort = self.sortable,
    )

def _depset_file_subject_new(files, meta, container_name = "depset", element_plural_name = "files"):
    """Creates a DepsetFileSubject asserting on `files`.

    Method: DepsetFileSubject.new

    Args:
        files: depset of Files.
        meta: ExpectMeta struct.
        container_name: str; conceptual name of the container.
        element_plural_name: str; the plural word for the values in the container.
    Returns:
        A struct representing a DepsetFile object.
    """

    # buildifier: disable=uninitialized
    public = struct(
        # keep sorted start
        contains = lambda *a, **k: _depset_file_subject_contains(self, *a, **k),
        contains_any_in = lambda *a, **k: _depset_file_subject_contains_any_in(self, *a, **k),
        contains_at_least = lambda *a, **k: _depset_file_subject_contains_at_least(self, *a, **k),
        contains_at_least_predicates = lambda *a, **k: _depset_file_subject_contains_at_least_predicates(self, *a, **k),
        contains_exactly = lambda *a, **k: _depset_file_subject_contains_exactly(self, *a, **k),
        contains_predicate = lambda *a, **k: _depset_file_subject_contains_predicate(self, *a, **k),
        not_contains = lambda *a, **k: _depset_file_subject_not_contains(self, *a, **k),
        not_contains_predicate = lambda *a, **k: _depset_file_subject_not_contains_predicate(self, *a, **k),
        # keep sorted end
    )
    self = struct(
        files = _to_list(files),
        meta = meta,
        public = public,
        actual_paths = sorted([f.short_path for f in _to_list(files)]),
        container_name = container_name,
        element_plural_name = element_plural_name,
    )
    return public

def _depset_file_subject_contains(self, expected):
    """Asserts that the depset of files contains the provided path/file.

    Method: DepsetFileSubject.contains

    Args:
        self: implicitly added
        expected: string or File; If a string path is provided, it is compared
            to the short path of the files and are formatted using
            `ExpectMeta.format_str` and its current contextual keywords. Note
            that, when using File objects, two files' configurations must be the
            same for them to be considered equal.
    """
    if is_file(expected):
        actual = self.files
    else:
        expected = self.meta.format_str(expected)
        actual = self.actual_paths

    _collection_subject_new(
        actual,
        meta = self.meta,
        container_name = self.container_name,
        element_plural_name = self.element_plural_name,
    ).contains(expected)

def _depset_file_subject_contains_at_least(self, expected):
    """Asserts that the depset of files contains at least the provided paths.

    Method: DepsetFileSubject.contains_at_least

    Args:
        self: implicitly added
        expected: collection of strings or collection of Files; multiplicity
            is respected. If string paths are provided, they are compared to the
            short path of the files and are formatted using
            `ExpectMeta.format_str` and its current contextual keywords. Note
            that, when using File objects, two files' configurations must be the
            same for them to be considered equal.
    Returns:
        an `Ordered` struct (see `_ordered_incorrectly_new`).
    """
    expected = _to_list(expected)
    if len(expected) < 1 or is_file(expected[0]):
        actual = self.files
    else:
        expected = [self.meta.format_str(v) for v in expected]
        actual = self.actual_paths

    return _collection_subject_new(
        actual,
        meta = self.meta,
        container_name = self.container_name,
        element_plural_name = self.element_plural_name,
    ).contains_at_least(expected)

def _depset_file_subject_contains_any_in(self, expected):
    """Asserts that any of the values in `expected` exist.

    Method: DepsetFileSubject.contains_any_in

    Args:
        self: implicitly added.
        expected: collection of path strings or collection of Files; at least one
            of the values must exist. Note that, when using File objects,
            two files' configurations must be the same for them to be considered
            equal.
    """
    expected = _to_list(expected)
    if len(expected) < 1 or is_file(expected[0]):
        actual = self.files
    else:
        actual = self.actual_paths

    expected_map = {value: None for value in expected}

    _check_contains_predicate(
        actual,
        matcher = matching.is_in(expected_map),
        format_problem = lambda: _format_problem_missing_any_values(expected),
        format_actual = lambda: _format_actual_collection(
            actual,
            container_name = self.container_name,
        ),
        meta = self.meta,
    )

def _depset_file_subject_contains_at_least_predicates(self, matchers):
    """Assert that the depset is a subset of the given predicates.

    Method: DepsetFileSubject.contains_at_least_predicates

    The depset must match all the predicates. It can contain extra elements.
    The multiplicity of matchers is respected. Checking that the relative order
    of matches is the same as the passed-in matchers order can done by calling
    `in_order()`.

    Args:
        self: implicitly added.
        matchers: list of `Matcher` objects (see `matchers` struct) that
            accept File objects.

    Returns:
        an `Ordered` struct (see `_ordered_incorrectly_new`).
    """
    ordered = _check_contains_at_least_predicates(
        self.files,
        matchers,
        format_missing = lambda missing: _format_problem_predicates_did_not_match(
            missing,
            element_plural_name = self.element_plural_name,
            container_name = self.container_name,
        ),
        format_out_of_order = _format_problem_matched_out_of_order,
        format_actual = lambda: _format_actual_collection(
            self.files,
            name = self.container_name,
        ),
        meta = self.meta,
    )
    return ordered

def _depset_file_subject_contains_predicate(self, matcher):
    """Asserts that `matcher` matches at least one value.

    Method: DepsetFileSubject.contains_predicate

    Args:
        self: implicitly added.
        matcher: `Matcher` (see `matching` struct) that accepts `File` objects.
    """
    _check_contains_predicate(
        self.files,
        matcher = matcher,
        format_problem = matcher.desc,
        format_actual = lambda: _format_actual_collection(
            self.files,
            name = self.container_name,
        ),
        meta = self.meta,
    )

def _depset_file_subject_contains_exactly(self, paths):
    """Asserts the depset of files contains exactly the given paths.

    Method: DepsetFileSubject.contains_exactly

    Args:
        self: implicitly added.
        paths: collection of strings; the paths that must exist. These are
            compared to the `short_path` values of the files in the depset.
            All the paths, and no more, must exist.
    """
    paths = [self.meta.format_str(p) for p in _to_list(paths)]
    _check_contains_exactly(
        expect_contains = paths,
        actual_container = self.actual_paths,
        format_actual = lambda: _format_actual_collection(
            self.actual_paths,
            name = self.container_name,
        ),
        format_expected = lambda: _format_problem_expected_exactly(
            paths,
            sort = True,
        ),
        format_missing = lambda missing: _format_problem_missing_required_values(
            missing,
            sort = True,
        ),
        format_unexpected = lambda unexpected: _format_problem_unexpected_values(
            unexpected,
            sort = True,
        ),
        format_out_of_order = lambda matches: fail("Should not be called"),
        meta = self.meta,
    )

def _depset_file_subject_not_contains(self, short_path):
    """Asserts that `short_path` is not in the depset.

    Method: DepsetFileSubject.not_contains_predicate

    Args:
        self: implicitly added.
        short_path: str; the short path that should not be present.
    """
    short_path = self.meta.format_str(short_path)
    matcher = _match_custom(short_path, lambda f: f.short_path == short_path)
    _check_not_contains_predicate(self.files, matcher, meta = self.meta)

def _depset_file_subject_not_contains_predicate(self, matcher):
    """Asserts that nothing in the depset matches `matcher`.

    Method: DepsetFileSubject.not_contains_predicate

    Args:
        self: implicitly added.
        matcher: Matcher that must match; operates on File objects.
    """
    _check_not_contains_predicate(self.files, matcher, meta = self.meta)

def _execution_info_subject_new(info, *, meta):
    """Create a new `ExecutionInfoSubject`

    Method: ExecutionInfoSubject.new

    Args:
        info: A `testing.ExecutionInfo` provider struct
        meta: `ExpectMeta` struct of call chain information.

    Returns:
        `ExecutionInfoSubject` struct.
    """

    # buildifier: disable=uninitialized
    public = struct(
        # keep sorted start
        requirements = lambda *a, **k: _execution_info_subject_requirements(self, *a, **k),
        exec_group = lambda *a, **k: _execution_info_subject_exec_group(self, *a, **k),
        # keep sorted end
    )
    self = struct(
        actual = info,
        meta = meta,
    )
    return public

def _execution_info_subject_requirements(self):
    """Create a `DictSubject` for the requirements values.

    Method: ExecutionInfoSubject.requirements

    Args:
        self: implicitly added

    Returns:
        `DictSubject` of the requirements.
    """
    return _dict_subject_new(
        self.actual.requirements,
        meta = self.meta.derive("requirements()"),
    )

def _execution_info_subject_exec_group(self):
    """Create a `StrSubject` for the `exec_group` value.

    Method: ExecutionInfoSubject.exec_group

    Args:
        self: implicitly added

    Returns:
        A `StrSubject` for the exec group.
    """
    return _str_subject_new(
        self.actual.exec_group,
        meta = self.meta.derive("exec_group()"),
    )

def _file_subject_new(file, meta):
    """Creates a FileSubject asserting against the given file.

    Method: FileSubject.new

    Args:
        file: File; the file to assert against.
        meta: ExpectMeta struct.
    Returns:
        A struct representing a FileSubject.
    """

    # buildifier: disable=uninitialized
    public = struct(
        # keep sorted start
        equals = lambda *a, **k: _file_subject_equals(self, *a, **k),
        path = lambda *a, **k: _file_subject_path(self, *a, **k),
        short_path_equals = lambda *a, **k: _file_subject_short_path_equals(self, *a, **k),
        # keep sorted end
    )
    self = struct(file = file, meta = meta, public = public)
    return public

def _file_subject_equals(self, expected):
    """Asserts that `expected` references the same file as `self`.

    This uses Bazel's notion of File equality, which usually includes
    the configuration, owning action, internal hash, etc of a File. The
    particulars of comparison depend on the actual Java type implementing
    the File object (some ignore owner, for example).

    NOTE: This does not compare file content; Starlark cannot read files.

    NOTE: Same files generated by different owners are likely considered
    not equal to each other. The alternative for this is to assert the
    `File.path` paths are equal.

    Method: FileSubject.equals
    """

    if self.file == expected:
        return
    self.meta.add_failure(
        "expected: {}".format(expected),
        "actual: {}".format(self.file),
    )

def _file_subject_path(self):
    """Returns a `StrSubject` asserting on the files `path` value.

    Method: FileSubject.path
    """
    return _str_subject_new(
        self.file.path,
        meta = self.meta.derive("path()"),
    )

def _file_subject_short_path_equals(self, path):
    """Asserts the file's short path is equal to the given path.

    Method: FileSubject.short_path_equals

    Args:
        self: implicitly added.
        path: str; the value the file's `short_path` must be equal to.
    """
    path = self.meta.format_str(path)
    if path == self.file.short_path:
        return
    self.meta.add_failure(
        "expected: {}".format(path),
        "actual: {}".format(self.file.short_path),
    )

def _instrumented_files_info_subject_new(info, *, meta):
    """Creates a subject to assert on `InstrumentedFilesInfo` providers.

    Method: InstrumentedFilesInfoSubject.new

    Args:
        info: An `InstrumentedFilesInfo` provider instance.
        meta: ExpectMeta struct; the meta data about the call chain.

    Returns:
        An `InstrumentedFilesInfoSubject` struct.
    """
    self = struct(
        actual = info,
        meta = meta,
    )
    public = struct(
        actual = info,
        instrumented_files = lambda *a, **k: _instrumented_files_info_subject_instrumented_files(self, *a, **k),
        metadata_files = lambda *a, **k: _instrumented_files_info_subject_metadata_files(self, *a, **k),
    )
    return public

def _instrumented_files_info_subject_instrumented_files(self):
    """Returns a `DesetFileSubject` of the instrumented files.

    Method: InstrumentedFilesInfoSubject.instrumented_files

    Args:
        self: implicitly added
    """
    return _depset_file_subject_new(
        self.actual.instrumented_files,
        meta = self.meta.derive("instrumented_files()"),
    )

def _instrumented_files_info_subject_metadata_files(self):
    """Returns a `DesetFileSubject` of the metadata files.

    Method: InstrumentedFilesInfoSubject.metadata_files

    Args:
        self: implicitly added
    """
    return _depset_file_subject_new(
        self.actual.metadata_files,
        meta = self.meta.derive("metadata_files()"),
    )

def _int_subject_new(value, meta):
    """Create an "IntSubject" struct.

    Method: IntSubject.new

    Args:
        value: optional int; the value to perform asserts against; may be None.
        meta: ExpectMeta struct; the meta data about the call chain.
    Returns:
        A struct representing an "IntSubject".
    """
    if not types.is_int(value) and value != None:
        fail("int required, got: {}".format(_repr_with_type(value)))

    # buildifier: disable=uninitialized
    public = struct(
        # keep sorted start
        equals = lambda *a, **k: _int_subject_equals(self, *a, **k),
        is_greater_than = lambda *a, **k: _int_subject_is_greater_than(self, *a, **k),
        is_in = lambda *a, **k: _common_subject_is_in(self, *a, **k),
        not_equals = lambda *a, **k: _int_subject_not_equals(self, *a, **k),
        # keep sorted end
    )
    self = struct(actual = value, meta = meta)
    return public

def _int_subject_equals(self, other):
    """Assert that the subject is equal to the given value.

    Method: IntSubject.equals

    Args:
        self: implicitly added.
        other: number; value the subject must be equal to.
    """
    if self.actual == other:
        return
    self.meta.add_failure(
        "expected: {}".format(other),
        "actual: {}".format(self.actual),
    )

def _int_subject_is_greater_than(self, other):
    """Asserts that the subject is greater than the given value.

    Method: IntSubject.is_greater_than

    Args:
        self: implicitly added.
        other: number; value the subject must be greater than.
    """
    if self.actual != None and other != None and self.actual > other:
        return
    self.meta.add_failure(
        "expected to be greater than: {}".format(other),
        "actual: {}".format(self.actual),
    )

def _int_subject_not_equals(self, unexpected):
    """Assert that the int is not equal to `unexpected`.

    Method: IntSubject.not_equals

    Args:
        self: implicitly added
        unexpected: int; the value actual cannot equal.
    """
    return _check_not_equals(
        actual = self.actual,
        unexpected = unexpected,
        meta = self.meta,
    )

def _label_subject_new(label, meta):
    """Creates a new `LabelSubject` for asserting `Label` objects.

    Method: LabelSubject.new

    Args:
        label: Label; the label to check against.
        meta: ExpectMeta; the metadata about the call chain.

    Returns:
        `LabelSubject` struct.
    """

    # buildifier: disable=uninitialized
    public = struct(
        # keep sorted start
        equals = lambda *a, **k: _label_subject_equals(self, *a, **k),
        is_in = lambda *a, **k: _label_subject_is_in(self, *a, **k),
        # keep sorted end
    )
    self = struct(actual = label, meta = meta)
    return public

def _label_subject_equals(self, other):
    """Asserts the label is equal to `other`.

    Method: LabelSubject.equals

    Args:
        self: implicitly added.
        other: Label or str; the expected value. If a str is passed, it
            will be converted to a `Label` using the `Label` function.
    """
    if types.is_string(other):
        other = Label(other)
    if self.actual == other:
        return
    self.meta.add_failure(
        "expected: {}".format(other),
        "actual: {}".format(self.actual),
    )

def _label_subject_is_in(self, any_of):
    """Asserts that the label is any of the provided values.

    Args:
        self: implicitly added.
        any_of: collection of Labels or strs (that are parsable by Label).
    """
    any_of = [
        Label(v) if types.is_string(v) else v
        for v in _to_list(any_of)
    ]
    _common_subject_is_in(self, any_of)

def _dict_subject_new(actual, meta, container_name = "dict", key_plural_name = "keys"):
    """Creates a new `DictSubject`.

    Method: DictSubject.new

    Args:
        actual: dict; the dict to assert against.
        meta: ExpectMeta object.
        container_name: str; conceptual name of the dict.
        key_plural_name: str; the plural word for the keys of the dict.

    Returns:
        New `DictSubject` struct.
    """

    # buildifier: disable=uninitialized
    public = struct(
        contains_exactly = lambda *a, **k: _dict_subject_contains_exactly(self, *a, **k),
        contains_at_least = lambda *a, **k: _dict_subject_contains_at_least(self, *a, **k),
        contains_none_of = lambda *a, **k: _dict_subject_contains_none_of(self, *a, **k),
        keys = lambda *a, **k: _dict_subject_keys(self, *a, **k),
    )
    self = struct(
        actual = actual,
        meta = meta,
        container_name = container_name,
        key_plural_name = key_plural_name,
    )
    return public

def _dict_subject_contains_at_least(self, at_least):
    """Assert the dict has at least the entries from `at_least`.

    Method: DictSubject.contains_at_least

    Args:
        self: implicitly added.
        at_least: dict; the subset of keys/values that must exist. Extra
            keys are allowed. Order is not checked.
    """
    result = _compare_dicts(
        expected = at_least,
        actual = self.actual,
    )
    if not result.missing_keys and not result.incorrect_entries:
        return

    self.meta.add_failure(
        problem = _format_problem_dict_expected(
            expected = at_least,
            missing_keys = result.missing_keys,
            unexpected_keys = [],
            incorrect_entries = result.incorrect_entries,
            container_name = self.container_name,
            key_plural_name = self.key_plural_name,
        ),
        actual = "actual: {{\n{}\n}}".format(_format_dict_as_lines(self.actual)),
    )

def _dict_subject_contains_exactly(self, expected):
    """Assert the dict has exactly the provided values.

    Method: DictSubject.contains_exactly

    Args:
        self: implicitly added
        expected: dict; the values that must exist. Missing values or
            extra values are not allowed. Order is not checked.
    """
    result = _compare_dicts(
        expected = expected,
        actual = self.actual,
    )

    if (not result.missing_keys and not result.unexpected_keys and
        not result.incorrect_entries):
        return

    self.meta.add_failure(
        problem = _format_problem_dict_expected(
            expected = expected,
            missing_keys = result.missing_keys,
            unexpected_keys = result.unexpected_keys,
            incorrect_entries = result.incorrect_entries,
            container_name = self.container_name,
            key_plural_name = self.key_plural_name,
        ),
        actual = "actual: {{\n{}\n}}".format(_format_dict_as_lines(self.actual)),
    )

def _dict_subject_contains_none_of(self, none_of):
    """Assert the dict contains none of `none_of` keys/values.

    Method: DictSubject.contains_none_of

    Args:
        self: implicitly added
        none_of: dict; the keys/values that must not exist. Order is not
            checked.
    """
    result = _compare_dicts(
        expected = none_of,
        actual = self.actual,
    )
    none_of_keys = sorted(none_of.keys())
    if (sorted(result.missing_keys) == none_of_keys or
        sorted(result.incorrect_entries.keys()) == none_of_keys):
        return

    incorrect_entries = {}
    for key, not_expected in none_of.items():
        actual = self.actual[key]
        if actual == not_expected:
            incorrect_entries[key] = struct(
                actual = actual,
                expected = "<not {}>".format(not_expected),
            )

    self.meta.add_failure(
        problem = _format_problem_dict_expected(
            expected = none_of,
            missing_keys = [],
            unexpected_keys = [],
            incorrect_entries = incorrect_entries,
            container_name = self.container_name + " to be missing",
            key_plural_name = self.key_plural_name,
        ),
        actual = "actual: {{\n{}\n}}".format(_format_dict_as_lines(self.actual)),
    )

_IN_ORDER = struct(
    in_order = lambda: None,
)

def _dict_subject_keys(self):
    """Returns a `CollectionSubject` for the dict's keys.

    Method: DictSubject.keys

    Args:
        self: implicitly added
    Returns:
        `CollectionSubject` of the keys.
    """
    return _collection_subject_new(
        self.actual.keys(),
        meta = self.meta.derive("keys()"),
        container_name = "dict keys",
        element_plural_name = "keys",
    )

def _ordered_incorrectly_new(format_problem, format_actual, meta):
    """Creates a new `Ordered` object that fails due to incorrectly ordered values.

    This creates an Ordered object that always fails. If order is correct,
    use the _IN_ORDER constant.

    Args:
        format_problem: callable; accepts no args and returns string (the
            reported problem description).
        format_actual: callable; accepts not args and returns tring (the
            reported actual description).
        meta: ExpectMeta; used to report the failure.

    Returns:
        `Ordered` object.
    """
    self = struct(
        meta = meta,
        format_problem = format_problem,
        format_actual = format_actual,
    )
    public = struct(
        in_order = lambda *a, **k: _ordered_incorrectly_in_order(self, *a, **k),
    )
    return public

def _ordered_incorrectly_in_order(self):
    """Checks that the values were in order.

    Args:
        self: implicitly added.
    """
    self.meta.add_failure(self.format_problem(), self.format_actual())

def _run_environment_info_subject_new(info, *, meta):
    """Creates a new `RunEnvironmentInfoSubject`

    Method: RunEnvironmentInfoSubject.new

    Args:
        info: The provider instance struct.
        meta: `ExpectMeta` struct of call chain information.
    """

    # buildifier: disable=uninitialized
    public = struct(
        environment = lambda *a, **k: _run_environment_info_subject_environment(self, *a, **k),
        inherited_environment = lambda *a, **k: _run_environment_info_subject_inherited_environment(self, *a, **k),
    )
    self = struct(
        actual = info,
        meta = meta,
    )
    return public

def _run_environment_info_subject_environment(self):
    """Creates a `DictSubject` to assert on the environment dict.

    Method: RunEnvironmentInfoSubject.environment

    Args:
        self: implicitly added

    Returns:
        `DictSubject` of the str->str environment map.
    """
    return _dict_subject_new(
        self.actual.environment,
        meta = self.meta.derive("environment()"),
    )

def _run_environment_info_subject_inherited_environment(self):
    """Creates a `CollectionSubject` to assert on the inherited_environment list.

    Method: RunEnvironmentInfoSubject.inherited_environment

    Args:
        self: implicitly added

    Returns:
        `CollectionSubject` of the str inherited_environment list.
    """
    return _collection_subject_new(
        self.actual.inherited_environment,
        meta = self.meta.derive("inherited_environment()"),
    )

def _runfiles_subject_new(runfiles, meta, kind = None):
    """Creates a "RunfilesSubject" struct.

    Method: RunfilesSubject.new

    Args:
        runfiles: runfiles; the runfiles to check against.
        meta: `ExpectMeta` struct; the metadata about the call chain.
        kind: optional str; what type of runfiles they are, usually "data"
            or "default". If not known or not applicable, use None.

    Returns:
        A `RunfilesSubject` struct.
    """
    self = struct(
        runfiles = runfiles,
        meta = meta,
        kind = kind,
        actual_paths = sorted(runfiles_paths(meta.ctx.workspace_name, runfiles)),
    )
    public = struct(
        # keep sorted start
        actual = runfiles,
        contains = lambda *a, **k: _runfiles_subject_contains(self, *a, **k),
        contains_at_least = lambda *a, **k: _runfiles_subject_contains_at_least(self, *a, **k),
        contains_exactly = lambda *a, **k: _runfiles_subject_contains_exactly(self, *a, **k),
        contains_none_of = lambda *a, **k: _runfiles_subject_contains_none_of(self, *a, **k),
        contains_predicate = lambda *a, **k: _runfiles_subject_contains_predicate(self, *a, **k),
        not_contains = lambda *a, **k: _runfiles_subject_not_contains(self, *a, **k),
        not_contains_predicate = lambda *a, **k: _runfiles_subject_not_contains_predicate(self, *a, **k),
        # keep sorted end
    )
    return public

def _runfiles_subject_contains(self, expected):
    """Assert that the runfiles contains the provided path.

    Method: RunfilesSubject.contains

    Args:
        self: implicitly added.
        expected: str; the path to check is present. This will be formatted
            using `ExpectMeta.format_str` and its current contextual
            keywords. Note that paths are runfiles-root relative (i.e.
            you likely need to include the workspace name.)
    """
    expected = self.meta.format_str(expected)
    matcher = matching.equals_wrapper(expected)
    return _runfiles_subject_contains_predicate(self, matcher)

def _runfiles_subject_contains_at_least(self, paths):
    """Assert that the runfiles contains at least all of the provided paths.

    Method: RunfilesSubject.contains_at_least

    All the paths must exist, but extra paths are allowed. Order is not checked.
    Multiplicity is respected.

    Args:
        self: implicitly added.
        paths: collection[str] or runfiles; the paths that must exist. If
            a collection of strings is provided, they will be formatted using
            `meta.format_str`, so its template keywords can be directly passed.
            If a runfiles object is passed, it is converted to a set of
            path strings.
    """
    if is_runfiles(paths):
        paths = runfiles_paths(self.meta.ctx.workspace_name, paths)

    paths = [self.meta.format_str(p) for p in _to_list(paths)]

    # NOTE: We don't return Ordered because there isn't a well-defined order
    # between the different sub-objects within the runfiles.
    _collection_subject_new(
        self.actual_paths,
        meta = self.meta,
        element_plural_name = "paths",
        container_name = "{}runfiles".format(self.kind + " " if self.kind else ""),
    ).contains_at_least(paths)

def _runfiles_subject_contains_predicate(self, matcher):
    """Asserts that `matcher` matches at least one value.

    Method: RunfilesSubject.contains_predicate

    Args:
        self: implicitly added.
        matcher: callable that takes 1 positional arg (str path) and returns
            boolean.
    """
    _check_contains_predicate(
        self.actual_paths,
        matcher = matcher,
        format_problem = "expected to contain: {}".format(matcher.desc),
        format_actual = lambda: _format_actual_collection(
            self.actual_paths,
            name = "{}runfiles".format(self.kind + " " if self.kind else ""),
        ),
        meta = self.meta,
    )

def _runfiles_subject_contains_exactly(self, paths):
    """Asserts that the runfiles contains_exactly the set of paths

    Method: RunfilesSubject.contains_exactly

    Args:
        self: implicitly added.
        paths: collection of strings; the paths to check. These will be
            formatted using `meta.format_str`, so its template keywords can
            be directly passed. All the paths must exist in the runfiles exactly
            as provided, and no extra paths may exist.
    """
    paths = [self.meta.format_str(p) for p in _to_list(paths)]
    runfiles_name = "{}runfiles".format(self.kind + " " if self.kind else "")

    _check_contains_exactly(
        expect_contains = paths,
        actual_container = self.actual_paths,
        format_actual = lambda: _format_actual_collection(
            self.actual_paths,
            name = runfiles_name,
        ),
        format_expected = lambda: _format_problem_expected_exactly(paths, sort = True),
        format_missing = lambda missing: _format_problem_missing_required_values(
            missing,
            sort = True,
        ),
        format_unexpected = lambda unexpected: _format_problem_unexpected_values(
            unexpected,
            sort = True,
        ),
        format_out_of_order = lambda matches: fail("Should not be called"),
        meta = self.meta,
    )

def _runfiles_subject_contains_none_of(self, paths, require_workspace_prefix = True):
    """Asserts the runfiles contain none of `paths`.

    Method: RunfilesSubject.contains_none_of

    Args:
        self: implicitly added.
        paths: collection of str; the paths that should not exist. They should
            be runfiles root-relative paths (not workspace relative). The value
            is formatted using `ExpectMeta.format_str` and the current
            contextual keywords.
        require_workspace_prefix: bool; True to check that the path includes the
            workspace prefix. This is to guard against accidentallly passing a
            workspace relative path, which will (almost) never exist, and cause
            the test to always pass. Specify False if the file being checked for
            is _actually_ a runfiles-root relative path that isn't under the
            workspace itself.
    """
    formatted_paths = []
    for path in paths:
        path = self.meta.format_str(path)
        formatted_paths.append(path)
        if require_workspace_prefix:
            _runfiles_subject_check_workspace_prefix(self, path)

    _collection_subject_new(
        self.actual_paths,
        meta = self.meta,
    ).contains_none_of(formatted_paths)

def _runfiles_subject_not_contains(self, path, require_workspace_prefix = True):
    """Assert that the runfiles does not contain the given path.

    Method: RunfilesSubject.not_contains

    Args:
        self: implicitly added.
        path: str; the path that should not exist. It should be a runfiles
            root-relative path (not workspace relative). The value is formatted
            using `format_str`, so its template keywords can be directly
            passed.
        require_workspace_prefix: bool; True to check that the path includes the
            workspace prefix. This is to guard against accidentallly passing a
            workspace relative path, which will (almost) never exist, and cause
            the test to always pass. Specify False if the file being checked for
            is _actually_ a runfiles-root relative path that isn't under the
            workspace itself.
    """
    path = self.meta.format_str(path)
    if require_workspace_prefix:
        _runfiles_subject_check_workspace_prefix(self, path)

    if path in self.actual_paths:
        problem, actual = _format_failure_unexpected_value(
            container_name = "{}runfiles".format(self.kind + " " if self.kind else ""),
            unexpected = path,
            actual = self.actual_paths,
        )
        self.meta.add_failure(problem, actual)

def _runfiles_subject_not_contains_predicate(self, matcher):
    """Asserts that none of the runfiles match `matcher`.

    Method: RunfilesSubject.not_contains_predicate

    Args:
        self: implicitly added.
        matcher: `Matcher` that accepts a string (runfiles root-relative path).
    """
    _check_not_contains_predicate(self.actual_paths, matcher, meta = self.meta)

def _runfiles_subject_check_workspace_prefix(self, path):
    if not path.startswith(self.meta.ctx.workspace_name + "/"):
        fail("Rejecting path lacking workspace prefix: this often indicates " +
             "a bug. Include the workspace name as part of the path, or pass " +
             "require_workspace_prefix=False if the path is truly " +
             "runfiles-root relative, not workspace relative.\npath=" + path)

def _str_subject_new(actual, meta):
    """Creates a subject for asserting strings.

    Method: StrSubject.new

    Args:
        actual: str; the string to check against.
        meta: `ExpectMeta` struct of call chain information.

    Returns:
        A struct representing a "StrSubject".
    """
    self = struct(actual = actual, meta = meta)
    public = struct(
        # keep sorted start
        contains = lambda *a, **k: _str_subject_contains(self, *a, **k),
        equals = lambda *a, **k: _str_subject_equals(self, *a, **k),
        is_in = lambda *a, **k: _common_subject_is_in(self, *a, **k),
        not_equals = lambda *a, **k: _str_subject_not_equals(self, *a, **k),
        split = lambda *a, **k: _str_subject_split(self, *a, **k),
        # keep sorted end
    )
    return public

def _str_subject_contains(self, substr):
    """Assert that the subject contains the substring `substr`.

    Method: StrSubject.contains

    Args:
        self: implicitly added.
        substr: str; the substring to check for.
    """
    if substr in self.actual:
        return
    self.meta.add_failure(
        "expected to contain: {}".format(substr),
        "actual: {}".format(self.actual),
    )

def _str_subject_equals(self, other):
    """Assert that the subject string equals the other string.

    Method: StrSubject.equals

    Args:
        self: implicitly added.
        other: str; the expected value it should equal.
    """
    if self.actual == other:
        return
    self.meta.add_failure(
        "expected: {}".format(other),
        "actual: {}".format(self.actual),
    )

def _str_subject_not_equals(self, unexpected):
    """Assert that the string is not equal to `unexpected`.

    Method: BoolSubject.not_equals

    Args:
        self: implicitly added.
        unexpected: str; the value actual cannot equal.
    """
    return _check_not_equals(
        actual = self.actual,
        unexpected = unexpected,
        meta = self.meta,
    )

def _str_subject_split(self, sep):
    """Return a `CollectionSubject` for the actual string split by `sep`.

    Method: StrSubject.split
    """
    return _collection_subject_new(
        self.actual.split(sep),
        meta = self.meta.derive("split({})".format(repr(sep))),
        container_name = "split string",
        sortable = False,
        element_plural_name = "parts",
    )

def _target_subject_new(target, meta):
    """Creates a subject for asserting Targets.

    Method: TargetSubject.new

    Args:
        target: Target; the target to check against.
        meta: ExpectMeta struct; metadata about the call chain.

    Returns:
        struct representing a "TargetSubject"
    """
    self = struct(target = target, meta = meta)
    public = struct(
        # keep sorted start
        action_generating = lambda *a, **k: _target_subject_action_generating(self, *a, **k),
        action_named = lambda *a, **k: _target_subject_action_named(self, *a, **k),
        actual = target,
        attr = lambda *a, **k: _target_subject_attr(self, *a, **k),
        data_runfiles = lambda *a, **k: _target_subject_data_runfiles(self, *a, **k),
        default_outputs = lambda *a, **k: _target_subject_default_outputs(self, *a, **k),
        executable = lambda *a, **k: _target_subject_executable(self, *a, **k),
        failures = lambda *a, **k: _target_subject_failures(self, *a, **k),
        has_provider = lambda *a, **k: _target_subject_has_provider(self, *a, **k),
        label = lambda *a, **k: _target_subject_label(self, *a, **k),
        meta = meta,
        output_group = lambda *a, **k: _target_subject_output_group(self, *a, **k),
        provider = lambda *a, **k: _target_subject_provider(self, *a, **k),
        runfiles = lambda *a, **k: _target_subject_runfiles(self, *a, **k),
        tags = lambda *a, **k: _target_subject_tags(self, *a, **k),
        # keep sorted end
    )
    return public

def _target_subject_runfiles(self):
    """Creates a subject asserting on the target's default runfiles.

    Method: TargetSubject.runfiles

    Args:
        self: implicitly added.
    Returns:
        A RunfilesSubject struct (see `_runfiles_subject_new`)
    """
    meta = self.meta.derive("runfiles()")
    return _runfiles_subject_new(self.target[DefaultInfo].default_runfiles, meta, "default")

def _target_subject_tags(self):
    """Gets the target's tags as a `CollectionSubject`

    Method: TargetSubject.tags

    Args:
        self: implicitly added

    Returns:
        `CollectionSubject` asserting the target's tags.
    """
    return _collection_subject_new(
        _target_subject_get_attr(self, "tags"),
        self.meta.derive("tags()"),
    )

def _target_subject_get_attr(self, name):
    if TestingAspectInfo not in self.target:
        fail("TestingAspectInfo provider missing: if this is a second order or higher " +
             "dependency, the recursing testing aspect must be enabled.")

    attrs = self.target[TestingAspectInfo].attrs
    if not hasattr(attrs, name):
        fail("Attr '{}' not present for target {}".format(name, self.target.label))
    else:
        return getattr(attrs, name)

def _target_subject_data_runfiles(self):
    """Creates a subject asserting on the target's data runfiles.

    Method: TargetSubject.data_runfiles

    Args:
        self: implicitly added.
    Returns:
        A RunfilesSubject struct (see `_runfiles_subject_new`)
    """
    meta = self.meta.derive("data_runfiles()")
    return _runfiles_subject_new(self.target[DefaultInfo].data_runfiles, meta, "data")

def _target_subject_default_outputs(self):
    """Creates a subject asserting on the target's default outputs.

    Method: TargetSubject.default_outputs

    Args:
        self: implicitly added.
    Returns:
        A DepsetFileSubject struct (see `_depset_file_subject_new`).
    """
    meta = self.meta.derive("default_outputs()")
    return _depset_file_subject_new(self.target[DefaultInfo].files, meta)

def _target_subject_executable(self):
    """Creates a subject asesrting on the target's executable File.

    Method: TargetSubject.executable

    Args:
        self: implicitly added.
    Returns:
        a FileSubject struct (see `_file_subject_new).
    """
    meta = self.meta.derive("executable()")
    return _file_subject_new(self.target[DefaultInfo].files_to_run.executable, meta)

def _target_subject_failures(self):
    """Creates a subject asserting on the target's failure message strings.

    Method: TargetSubject.failures

    Args:
        self: implicitly added
    Returns:
        A CollectionSubject (of strs).
    """
    meta = self.meta.derive("failures()")
    if AnalysisFailureInfo in self.target:
        failure_messages = sorted([
            f.message
            for f in self.target[AnalysisFailureInfo].causes.to_list()
        ])
    else:
        failure_messages = []
    return _collection_subject_new(failure_messages, meta, container_name = "failure messages")

def _target_subject_has_provider(self, provider):
    """Asserts that the target as provider `provider`.

    Method: TargetSubject.has_provider

    Args:
        self: implicitly added.
        provider: The provider object to check for.
    """
    if self.meta.has_provider(self.target, provider):
        return
    self.meta.add_failure(
        "expected to have provider: {}".format(_provider_name(provider)),
        "but provider was not found",
    )

def _target_subject_label(self):
    """Returns a `LabelSubject` for the target's label value.

    Method: TargetSubject.label
    """
    return _label_subject_new(
        label = self.target.label,
        meta = self.meta.derive(expr = "label()"),
    )

def _target_subject_output_group(self, name):
    """Returns a DepsetFileSubject of the files in the named output group.

    Method: TargetSubject.output_group

    Args:
        self: implicitly added.
        name: str, an output group name. If it isn't present, an error is raised.

    Returns:
        DepsetFileSubject of the named output group.
    """
    info = self.target[OutputGroupInfo]
    if not hasattr(info, name):
        fail("OutputGroupInfo.{} not present for target {}".format(name, self.target.label))
    return _depset_file_subject_new(
        getattr(info, name),
        meta = self.meta.derive("output_group({})".format(name)),
    )

def _target_subject_provider(self, provider_key, factory = None):
    """Returns a subject for a provider in the target.

    Method: TargetSubject.provider

    Args:
        self: implicitly added.
        provider_key: The provider key to create a subject for
        factory: optional callable. The factory function to use to create
            the subject for the found provider. Required if the provider key is
            not an inherently supported provider. It must have the following
            signature: `def factory(value, /, *, meta)`.

    Returns:
        A subject wrapper of the provider value.
    """
    if not factory:
        for key, value in _PROVIDER_SUBJECT_FACTORIES:
            if key == provider_key:
                factory = value
                break

    if not factory:
        fail("Unsupported provider: {}".format(provider_key))
    info = self.target[provider_key]

    return factory(
        info,
        meta = self.meta.derive("provider({})".format(provider_key)),
    )

def _target_subject_action_generating(self, short_path):
    """Get the single action generating the given path.

    Method: TargetSubject.action_generating

    NOTE: in order to use this method, the target must have the `TestingAspectInfo`
    provider (added by the `testing_aspect` aspect.)

    Args:
        self: implicitly added.
        short_path: str; the output's short_path to match. The value is
            formatted using `format_path`, so its template keywords can be
            directly passed.
    Returns:
        `ActionSubject` for the matching action. If no action is found, or
        more than one action matches, then an error is raised.
    """

    if not self.meta.has_provider(self.target, TestingAspectInfo):
        fail("TestingAspectInfo provider missing: if this is a second order or higher " +
             "dependency, the recursing testing aspect must be enabled.")

    short_path = self.meta.format_str(short_path)
    actions = []
    for action in self.meta.get_provider(self.target, TestingAspectInfo).actions:
        for output in action.outputs.to_list():
            if output.short_path == short_path:
                actions.append(action)
                break
    if not actions:
        fail("No action generating '{}'".format(short_path))
    elif len(actions) > 1:
        fail("Expected 1 action to generate '{output}', found {count}: {actions}".format(
            output = short_path,
            count = len(actions),
            actions = "\n".join([str(a) for a in actions]),
        ))
    action = actions[0]
    meta = self.meta.derive(
        expr = "action_generating({})".format(short_path),
        details = ["action: [{}] {}".format(action.mnemonic, action)],
    )
    return _action_subject_new(action, meta)

def _target_subject_action_named(self, mnemonic):
    """Get the single action with the matching mnemonic.

    Method: TargetSubject.action_named

    NOTE: in order to use this method, the target must have the `TestingAspectInfo`
    provider (added by the `testing_aspect` aspect.)

    Args:
        self: implicitly added.
        mnemonic: str; the mnemonic to match

    Returns:
        ActionSubject. If no action matches, or more than one action matches, an error
        is raised.
    """
    if TestingAspectInfo not in self.target:
        fail("TestingAspectInfo provider missing: if this is a second order or higher " +
             "dependency, the recursing testing aspect must be enabled.")
    actions = [a for a in self.target[TestingAspectInfo].actions if a.mnemonic == mnemonic]
    if not actions:
        fail(
            "No action named '{name}' for target {target}.\nFound: {found}".format(
                name = mnemonic,
                target = self.target.label,
                found = _enumerate_list_as_lines([
                    a.mnemonic
                    for a in self.target[TestingAspectInfo].actions
                ]),
            ),
        )
    elif len(actions) > 1:
        fail("Expected 1 action to match '{name}', found {count}: {actions}".format(
            name = mnemonic,
            count = len(actions),
            actions = "\n".join([str(a) for a in actions]),
        ))
    action = actions[0]
    meta = self.meta.derive(
        expr = "action_named({})".format(mnemonic),
        details = ["action: [{}] {}".format(action.mnemonic, action)],
    )
    return _action_subject_new(action, meta)

# NOTE: This map should only have attributes that are common to all target
# types, otherwise we can't rely on an attribute having a specific type.
_ATTR_NAME_TO_SUBJECT_FACTORY = {
    "testonly": _bool_subject_new,
}

def _target_subject_attr(self, name, *, factory = None):
    """Gets a subject-wrapped value for the named attribute.

    Method: TargetSubject.attr

    NOTE: in order to use this method, the target must have the `TestingAspectInfo`
    provider (added by the `testing_aspect` aspect.)

    Args:
        self: implicitly added
        name: str; the attribute to get. If it's an unsupported attribute, and
            no explicit factory was provided, an error will be raised.
        factory: callable; function to create the returned subject based on
            the attribute value. If specified, it takes precedence over the
            attributes that are inherently understood. It must have the
            following signature: `def factory(value, *, meta)`, where `value` is
            the value of the attribute, and `meta` is the call chain metadata.

    Returns:
        A Subject-like object for the given attribute. The particular subject
        type returned depends on attribute and `factory` arg. If it isn't know
        what type of subject to use for the attribute, an error is raised.
    """
    if TestingAspectInfo not in self.target:
        fail("TestingAspectInfo provider missing: if this is a second order or higher " +
             "dependency, the recursing testing aspect must be enabled.")

    attr_value = getattr(self.target[TestingAspectInfo].attrs, name)
    if not factory:
        if name not in _ATTR_NAME_TO_SUBJECT_FACTORY:
            fail("Unsupported attr: {}".format(name))
        factory = _ATTR_NAME_TO_SUBJECT_FACTORY[name]

    return factory(
        attr_value,
        meta = self.meta.derive("attr({})".format(name)),
    )

# Providers aren't hashable, so we have to use a list of (key, value)
_PROVIDER_SUBJECT_FACTORIES = [
    (InstrumentedFilesInfo, _instrumented_files_info_subject_new),
    (RunEnvironmentInfo, _run_environment_info_subject_new),
    (testing.ExecutionInfo, _execution_info_subject_new),
]

def _check_contains_exactly(
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
        format_actual: callable; accepts no args and returns str (the
            description of the actual values).
        format_expected: callable; accepts no args and returns str (
            description of the expected values).
        format_missing: callable; accepts 1 position arg (list of values from
            `expect_contains` that were missing), and returns str (description of
            the missing values).
        format_unexpected: callable; accepts 1 positional arg (list of values from
           `actual_container` that weren't expected), and returns str (description of
           the unexpected values).
        format_out_of_order: callable; accepts 1 arg (a list of "MatchResult"
            structs, see above) and returns a string (the problem message
            reported on failure). The order of match results is the expected
            order.
        meta: ExceptMeta struct to record failures.
    """
    result = _compare_contains_exactly_predicates(
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
        return _IN_ORDER
    elif result.is_in_order:
        return _IN_ORDER
    else:
        return _ordered_incorrectly_new(
            format_problem = lambda: format_out_of_order(result.matches),
            format_actual = format_actual,
            meta = meta,
        )

def _check_contains_exactly_predicates(
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
        format_actual: callable; accepts no args and returns str (the
            description of the actual values).
        format_expected: callable; accepts no args and returns str (
            description of the expected values).
        format_missing: callable; accepts 1 position arg (list of values from
            `expect_contains` that were missing), and returns str (description of
            the missing values).
        format_unexpected: callable; accepts 1 positional arg (list of values from
           `actual_container` that weren't expected), and returns str (description of
           the unexpected values).
        format_out_of_order: callable; accepts 1 arg (a list of "MatchResult"
            structs, see above) and returns a string (the problem message
            reported on failure). The order of match results is the expected
            order.
        meta: ExceptMeta struct to record failures.
    """
    result = _compare_contains_exactly_predicates(
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
        return _IN_ORDER
    elif result.is_in_order:
        return _IN_ORDER
    else:
        return _ordered_incorrectly_new(
            format_problem = lambda: format_out_of_order(result.matches),
            format_actual = format_actual,
            meta = meta,
        )

def _check_contains_predicate(collection, matcher, *, format_problem, format_actual, meta):
    """Check that `matcher` matches any value in `collection`, and record an error if not.

    Args:
        collection: collection; the collection whose values are compared against.
        matcher: Matcher that must match.
        format_problem: str or callable; If a string, then the problem message
            to use when failing. If a callable, a no-arg callable that returns
            the problem string; see `_format_problem_*` for existing helpers.
        format_actual: str or callable; If a string, then the actual message
            to use when failing. If a callable, a no-arg callable that returns
            the actual string; see `_format_actual_*` for existing helpers.
        meta: ExceptMeta struct to record failures
    """
    for value in collection:
        if matcher.match(value):
            return
    meta.add_failure(
        format_problem if types.is_string(format_problem) else format_problem(),
        format_actual if types.is_string(format_actual) else format_actual(),
    )

def _check_contains_at_least_predicates(
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
        collection: collection of values to check within.
        matchers: collection of `Matcher` objects to match (see `matchers` struct)
        format_missing: callable; accepts 1 positional arg (a list of the
            `matchers` that did not match) and returns a string (the problem
            message reported on failure).
        format_out_of_order: callable; accepts 1 arg (a list of `MatchResult`s)
            and returns a string (the problem message reported on failure). The
            order of match results is the expected order.
        format_actual: callable: accepts no args and returns a string (the
            text describing the actual value reported on failure).
        meta: ExpectMeta struct; used for reporting errors.
    Returns:
        `Ordered` object to allow checking the order of matches.
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
            matches[orig_matcher_pos] = _match_result_new(
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
        return _IN_ORDER
    elif ordered:
        return _IN_ORDER
    else:
        return _ordered_incorrectly_new(
            format_problem = lambda: format_out_of_order(matches),
            format_actual = format_actual,
            meta = meta,
        )

def _check_contains_none_of(*, collection, none_of, meta, sort = True):
    """Check that a collection does not have any of the `none_of` values.

    Args:
        collection: the collection to values to check within
        none_of: the values that should not exist
        meta: ExceptMeta struct to record failures
        sort: bool; If true, sort the values for display.
    """
    unexpected = []
    for value in none_of:
        if value in collection:
            unexpected.append(value)
    if not unexpected:
        return

    unexpected = _maybe_sorted(unexpected, sort)
    problem, actual = _format_failure_unexpected_values(
        none_of = "\n" + _enumerate_list_as_lines(unexpected, prefix = "  "),
        unexpected = unexpected,
        actual = collection,
        sort = sort,
    )
    meta.add_failure(problem, actual)

def _check_not_contains_predicate(collection, matcher, *, meta, sort = True):
    """Check that `matcher` matches no values in `collection`.

    Args:
        collection: collection; the collection whose values are compared against.
        matcher: Matcher that must not match.
        meta: ExceptMeta struct to record failures
        sort: bool; If true, the collection will be sorted for display.
    """
    matches = _maybe_sorted([v for v in collection if matcher.match(v)], sort)
    if not matches:
        return
    problem, actual = _format_failure_unexpected_values(
        none_of = matcher.desc,
        unexpected = matches,
        actual = collection,
        sort = sort,
    )
    meta.add_failure(problem, actual)

def _common_subject_is_in(self, any_of):
    """Generic implementation of `Subject.is_in`

    Args:
        self: The subject object. It must provide `actual` and `meta`
            attributes.
        any_of: collection of values.
    """
    return _check_is_in(self.actual, _to_list(any_of), self.meta)

def _check_is_in(actual, any_of, meta):
    """Check that `actual` is one of the values in `any_of`.

    Args:
        actual: value to check for in `any_of`
        any_of: collection of values to check within.
        meta: ExpectMeta struct to record failures
    """
    if actual in any_of:
        return
    meta.add_failure(
        "expected any of:\n{}".format(
            _enumerate_list_as_lines(any_of, prefix = "  "),
        ),
        "actual: {}".format(actual),
    )

def _check_not_equals(*, unexpected, actual, meta):
    """Check that the values are the same type and not equal (according to !=).

    NOTE: This requires the same type for both values. This is to prevent
    mistakes where different data types (usually) can never be equal.

    Args:
        unexpected: object; the value that actual cannot equal
        actual: object; the observed value
        meta: ExpectMeta object to record failures
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

def _match_result_new(*, found_at, matched_value, matcher):
    """Creates a "MatchResult" struct.

    A `MatchResult` struct is information about how an expected value
    matched to an actual value.

    Args:
        found_at: int; the position in the actual container the match
            occurred at.
        matched_value: the actual value that caused the match
        matcher: Matcher or value that matched

    """
    return struct(
        found_at = found_at,
        matched_value = matched_value,
        matcher = matcher,
    )

def _compare_contains_exactly_predicates(*, expect_contains, actual_container):
    """Tells how and if values and predicates correspond 1:1 in the specified order.

    * There must be a 1:1 correspondence between the container values and the
      predicates.
    * Multiplicity is respected (i.e., if the same predicate occurs twice, then
      two distinct elements must match).
    * Matching occurs in first-seen order. That is, a predicate will "consume"
      the first value in `actual_container` it matches.
    * The collection must match all the predicates, no more or less.
    * Checking that the order of matches is the same as the passed-in matchers
      order can be done by call `in_order()`.

    Note that confusing results may occur if predicates with overlapping
    match conditions are used. For example, given:
      actual=["a", "ab", "abc"],
      predicates=[<contains a>, <contains b>, <equals a>]

    Then the result will be they aren't equal: the first two predicates
    consume "a" and "ab", leaving only "abc" for the <equals a> predicate
    to match against, which fails.

    Args:
        expect_contains: collection of `Matcher`s; the predicates that must match.
            To perform simple equalty, use `matching.equals_wrapper()`.
        actual_container: collection; The container to check within.
    Returns:
        struct with the following attributes:
        * contains_exactly: bool; True if all the predicates (and no others)
              matched a distinct element; does not consider order.
        * is_in_order: bool; True if the actuals values matched in the same
              order as the expected predicates. False if they were out of order.
              If `contains_exactly=False`, this attribute is undefined.
        * missing: list; `Matcher`s from `expect_contains` that did not find a
              corresponding element in `actual_container`.
        * unexpected: list; values from `actual_container` that were not
              present in `expect_contains`.
        * matches: list of MatchResult; Information about which elements in
              the two lists that matched each other. If
              `contains_exactly=False`, this attribute is undefined.
    """

    # The basic idea is treating the expected and actual lists as queues of
    # remaining values to search for. This allows the multiplicity of values
    # to be respected and ordering correctness to be computed.
    #
    # Each iteration, we "pop" an element off each queue and...
    #   * If the elements are equal, then all is good: ordering is still
    #     possible, and the required element is present. Start a new iteration.
    #   * Otherwise, we know ordering isn't possible anymore and need to
    #     answer two questions:
    #       1. Is the actual value extra, or elsewhere in the expected values?
    #       2. Is the expected value missing, or elsewhere in the actual values?
    #     If a value exists elsewhere in the other queue, then we have to
    #     remove it to prevent it from being searched for again in a later
    #     iteration.
    # As we go along, we keep track of where expected values matched; this
    # allows for better error reporting.
    expect_contains = _to_list(expect_contains)
    actual_container = _to_list(actual_container)

    actual_queue = []  # List of (original pos, value)
    for i, value in enumerate(actual_container):
        actual_queue.append([i, value])

    expected_queue = []  # List of (original pos, value)
    matches = []  # List of "MatchResult" structs
    for i, value in enumerate(expect_contains):
        expected_queue.append([i, value])
        matches.append(None)

    missing = []  # List of expected values missing
    unexpected = []  # List of actual values that weren't expected
    ordered = True

    # Start at -1 because the first iteration adds 1
    actual_pos = -1
    expected_pos = -1
    loop = range(max(len(actual_queue), len(expected_queue)))
    for _ in loop:
        # Advancing the position is equivalent to removing the queues's head
        actual_pos += 1
        expected_pos += 1
        if actual_pos >= len(actual_queue) and expected_pos >= len(expected_queue):
            # Can occur when e.g. actual=[A, B], expected=[B]
            break
        if actual_pos >= len(actual_queue):
            # Fewer actual values than expected, so the rest are missing
            missing.extend([v[1] for v in expected_queue[expected_pos:]])
            break
        if expected_pos >= len(expected_queue):
            # More actual values than expected, so the rest are unexpected
            unexpected.extend([v[1] for v in actual_queue[actual_pos:]])
            break

        actual_entry = actual_queue[actual_pos]
        expected_entry = expected_queue[expected_pos]

        if expected_entry[1].match(actual_entry[1]):
            continue  # Happy path: both are equal and order is maintained.
        ordered = False
        found_at, found_entry = _list_find(
            actual_queue,
            lambda v: expected_entry[1].match(v[1]),
            start = actual_pos,
            end = len(actual_queue),
        )
        if found_at == -1:
            missing.append(expected_entry[1])
        else:
            # Remove it from the queue so a subsequent iteration doesn't
            # try to search for it again.
            actual_queue.pop(found_at)
            matches[expected_entry[0]] = _match_result_new(
                found_at = found_entry[0],
                matched_value = found_entry[1],
                matcher = expected_entry[1],
            )

        found_at, found_entry = _list_find(
            expected_queue,
            lambda entry: entry[1].match(actual_entry[1]),
            start = expected_pos,
            end = len(expected_queue),
        )
        if found_at == -1:
            unexpected.append(actual_entry[1])
        else:
            # Remove it from the queue so a subsequent iteration doesn't
            # try to search for it again.
            expected_queue.pop(found_at)
            matches[found_entry[0]] = _match_result_new(
                found_at = actual_entry[0],
                matched_value = actual_entry[1],
                matcher = found_entry[1],
            )

    return struct(
        contains_exactly = not (missing or unexpected),
        is_in_order = ordered,
        missing = missing,
        unexpected = unexpected,
        matches = matches,
    )

def _list_find(search_in, search_for, *, start = 0, end = None):
    """Linear search a list for a value matching a predicate.

    Args:
        search_in: list; the list to search within.
        search_for: callable; accepts 1 positional arg (the current value)
            and returns bool (True if matched).
        start: int; the position within `search_in` to start at. Defaults
            to 0 (start of list)
        end: optional int; the position within `search_in` to stop before (i.e.
            the value is exclusive; given a list of length 5, specifying `end=5`
            means it will search the whole list). Defaults to the length of
            `search_in`.
    Returns:
        Tuple of (int found_at, value).
        * If the value was found, then `found_at` is the offset in `search_in`
          it was found at, and matched value is the element at that offset.
        * If the value was not found, then `found_at=-1`, and the matched
          value is None.
    """
    end = len(search_in) if end == None else end
    pos = start
    for _ in search_in:
        if pos >= end:
            return -1, None
        value = search_in[pos]
        if search_for(value):
            return pos, value
        pos += 1
    return -1, None

def _compare_dicts(*, expected, actual):
    """Compares two dicts, reporting differences.

    Args:
        expected: dict; the desired state of `actual`
        actual: dict; the observed dict
    Returns:
        Struct with the following attributes:
        * missing_keys: list of keys that were missing in `actual`, but present
          in `expected`
        * unexpected_keys: list of keys that were present in `actual`, but not
          present in `expected`
        * incorrect_entries: dict of key -> DictEntryMismatch; of keys that
          were in both dicts, but whose values were not equal. The value is
          a "DictEntryMismatch" struct, which is defined as a struct with
          attributes:
            * actual: the value from `actual[key]`
            * expected: the value from `expected[key]`
    """
    all_keys = {key: None for key in actual.keys()}
    all_keys.update({key: None for key in expected.keys()})
    missing_keys = []
    unexpected_keys = []
    incorrect_entries = {}

    for key in sorted(all_keys):
        if key not in actual:
            missing_keys.append(key)
        elif key not in expected:
            unexpected_keys.append(key)
        else:
            actual_value = actual[key]
            expected_value = expected[key]
            if actual_value != expected_value:
                incorrect_entries[key] = struct(
                    actual = actual_value,
                    expected = expected_value,
                )

    return struct(
        missing_keys = missing_keys,
        unexpected_keys = unexpected_keys,
        incorrect_entries = incorrect_entries,
    )

def _format_actual_collection(actual, name = "values", sort = True):
    """Creates an error message for the observed values of a collection.

    Args:
        actual: collection; the values to show
        name: str; the conceptual name of the collection.
        sort: bool; If true, the collection will be sorted for display.
    Returns:
        str; the formatted error message.
    """
    actual = _maybe_sorted(actual, sort)
    return "actual {name}:\n{actual}".format(
        name = name,
        actual = _enumerate_list_as_lines(actual, prefix = "  "),
    )

def _format_failure_missing_all_values(
        element_plural_name,
        container_name,
        *,
        missing,
        actual,
        sort = True):
    """Create error messages when a container is missing all the expected values.

    Args:
        element_plural_name: str; the plural word for the values in the container.
        container_name: str; the conceptual name of the container.
        missing: the collection of values that are missing.
        actual: the collection of values observed.
        sort: bool; if True, then missing and actual are sorted. If False, they
            are not sorted.

    Returns:
        Tuple of (str problem, str actual), suitable for passing to ExpectMeta's
        `add_failure()` method.
    """
    missing = _maybe_sorted(missing, sort)
    problem_msg = "{count} expected {name} missing from {container}:\n{missing}".format(
        count = len(missing),
        name = element_plural_name,
        container = container_name,
        missing = _enumerate_list_as_lines(missing, prefix = "  "),
    )
    actual_msg = _format_actual_collection(actual, name = container_name, sort = sort)
    return problem_msg, actual_msg

def _format_failure_unexpected_values(*, none_of, unexpected, actual, sort = True):
    """Create error messages when a container has unexpected values.

    Args:
        none_of: str; description of the values that were not expected to be
            present.
        unexpected: collection; the values that were unexpectedly found.
        actual: collection; the observed values.
        sort: bool; True if the collections should be sorted for output.

    Returns:
        Tuple of (str problem, str actual), suitable for passing to ExpectMeta's
        `add_failure()` method.
    """
    unexpected = _maybe_sorted(unexpected, sort)
    problem_msg = "expected not to contain any of: {none_of}\nbut {count} found:\n{unexpected}".format(
        none_of = none_of,
        count = len(unexpected),
        unexpected = _enumerate_list_as_lines(unexpected, prefix = "  "),
    )
    actual_msg = _format_actual_collection(actual, sort = sort)
    return problem_msg, actual_msg

def _format_failure_unexpected_value(container_name, unexpected, actual, sort = True):
    """Create error messages when a container contains a specific unexpected value.

    Args:
        container_name: str; conceptual name of the container.
        unexpected: the value that shouldn't have been in `actual`.
        actual: collection; the observed values.
        sort: bool; True if the collections should be sorted for output.

    Returns:
        Tuple of (str problem, str actual), suitable for passing to ExpectMeta's
        `add_failure()` method.
    """
    problem_msg = "expected not to contain: {}".format(unexpected)
    actual_msg = _format_actual_collection(actual, name = container_name, sort = sort)
    return problem_msg, actual_msg

def _format_problem_dict_expected(
        *,
        expected,
        missing_keys,
        unexpected_keys,
        incorrect_entries,
        container_name = "dict",
        key_plural_name = "keys"):
    """Formats an expected dict, describing what went wrong.

    Args:
        expected: dict, the full expected value.
        missing_keys: list, the keys that were not found.
        unexpected_keys: list, the keys that should not have existed
        incorrect_entries: list of `DictEntryMismatch` struct (see _compare_dict).
        container_name: str; conceptual name of the dict.
        key_plural_name: str; the plural word for the keys of the dict.
    Returns:
        str; the problem string
    """
    problem_lines = ["expected {}: {{\n{}\n}}".format(
        container_name,
        _format_dict_as_lines(expected),
    )]
    if missing_keys:
        problem_lines.append("{count} missing {key_plural_name}:\n{keys}".format(
            count = len(missing_keys),
            key_plural_name = key_plural_name,
            keys = _enumerate_list_as_lines(sorted(missing_keys), prefix = "  "),
        ))
    if unexpected_keys:
        problem_lines.append("{count} unexpected {key_plural_name}:\n{keys}".format(
            count = len(unexpected_keys),
            key_plural_name = key_plural_name,
            keys = _enumerate_list_as_lines(sorted(unexpected_keys), prefix = "  "),
        ))
    if incorrect_entries:
        problem_lines.append("{} incorrect entries:".format(len(incorrect_entries)))
        for key, mismatch in incorrect_entries.items():
            problem_lines.append("key {}:".format(key))
            problem_lines.append("  expected: {}".format(mismatch.expected))
            problem_lines.append("  but was : {}".format(mismatch.actual))
    return "\n".join(problem_lines)

def _format_problem_expected_exactly(expected, sort = True):
    """Creates an error message describing the expected values.

    This is for use when the observed value must have all the values and
    no more.

    Args:
        expected: collection of values
        sort: bool; True if to sort the values for display.
    Returns:
        str; the formatted problem message
    """
    expected = _maybe_sorted(expected, sort)
    return "expected exactly:\n{}".format(
        _enumerate_list_as_lines(expected, prefix = "  "),
    )

def _format_problem_missing_any_values(any_of, sort = True):
    """Create an error message for when any of a collection of values are missing.

    Args:
        any_of: collection; the set of values, any of which were missing.
        sort: bool; True if the collection should be sorted for display.
    Returns:
        str; the problem description string.
    """
    any_of = _maybe_sorted(any_of, sort)
    return "expected to contain any of:\n{}".format(
        _enumerate_list_as_lines(any_of, prefix = "  "),
    )

def _format_problem_missing_required_values(missing, sort = True):
    """Create an error message for when the missing values must all be present.

    Args:
        missing: collection; the values that must all be present.
        sort: bool; True if to sort the values for display
    Returns:
        str; the problem description string.
    """
    missing = _maybe_sorted(missing, sort)
    return "{count} missing:\n{missing}".format(
        count = len(missing),
        missing = _enumerate_list_as_lines(missing, prefix = "  "),
    )

def _format_problem_predicates_did_not_match(
        missing,
        *,
        element_plural_name = "elements",
        container_name = "values"):
    """Create an error message for when a list of predicates didn't match.

    Args:
        missing: list of `Matcher` objects (see `_match_custom`).
        element_plural_name: str; the plural word for the values in the container.
        container_name: str; the conceptual name of the container.
    Returns:
        str; the problem description string.
    """

    return "{count} expected {name} missing from {container}:\n{missing}".format(
        count = len(missing),
        name = element_plural_name,
        container = container_name,
        missing = _enumerate_list_as_lines(
            [m.desc for m in missing],
            prefix = "  ",
        ),
    )

def _format_problem_matched_out_of_order(matches):
    """Create an error message for when a expected values matched in the wrong order.

    Args:
        matches: list of `MatchResult` objects; see `_check_contains_at_least_predicates()`.
    Returns:
        str; the problem description string.
    """
    format_matched_value = _guess_format_value([m.matched_value for m in matches])

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
        _enumerate_list_as_lines(matches, format_value = format_value, prefix = "  "),
    )

def _format_problem_unexpected_values(unexpected, sort = True):
    """Create an error message for when there are unexpected values.

    Args:
        unexpected: list of unexpected values.
        sort: bool; true if the values should be sorted for output.

    Returns:
        str; the problem description string.
    """
    unexpected = _maybe_sorted(unexpected, sort)
    return "{count} unexpected:\n{unexpected}".format(
        count = len(unexpected),
        unexpected = _enumerate_list_as_lines(unexpected, prefix = "  "),
    )

def _provider_name(provider):
    # This relies on implementation details of how Starlark represents
    # providers, and isn't entirely accurate, but works well enough
    # for error messages.
    return str(provider).split("<function ")[1].split(">")[0]

def _repr_with_type(value):
    return "<{} {}>".format(type(value), repr(value))

def _informative_str(value):
    value_str = str(value)
    if not value_str:
        return "<empty string ∅>"
    elif value_str != value_str.strip():
        return '"{}" <sans quotes; note whitespace within>'.format(value_str)
    else:
        return value_str

def _enumerate_list_as_lines(values, prefix = "", format_value = None):
    """Format a list of values in a human-friendly list.

    Args:
        values: list of values
        prefix: str; prefix to add before each line item.
        format_value: optional callable to convert each value to a string.
            If not specified, then an appropriate converter will be inferred
            based on the values. If specified, then the callable must accept
            1 positional arg and return a string.
    Returns:
        str; the values formatted as a human-friendly list.
    """
    if not values:
        return "{}<empty>".format(prefix)

    if format_value == None:
        format_value = _guess_format_value(values)

    # Subtract 1 because we start at 0; i.e. length 10 prints 0 to 9
    max_i_width = len(str(len(values) - 1))

    return "\n".join([
        "{prefix}{ipad}{i}: {value}".format(
            prefix = prefix,
            ipad = " " * (max_i_width - len(str(i))),
            i = i,
            value = format_value(v),
        )
        for i, v in enumerate(values)
    ])

def _format_dict_as_lines(mapping, prefix = "", format_value = None, sort = True):
    """Format a dictionary as lines of key->value for easier reading.

    Args:
        mapping: dict to show
        prefix: str; prefix to prepend to every line.
        format_value: callable; takes a value from the dictionary to show and
            returns the string that shown be shown. If not specified, one
            will be automatically determined from the dictionary's values.
        sort: bool; true if the output should be sorted by dict key (if
            the keys are sortable).
    """
    lines = []
    if not mapping:
        return "  <empty dict>"
    format_value = _guess_format_value(mapping.values())
    keys = _maybe_sorted(mapping.keys(), sort)

    max_key_width = max([len(str(key)) for key in keys])

    for key in keys:
        lines.append("{prefix}  {key}{pad}: {value}".format(
            prefix = prefix,
            key = key,
            pad = " " * (max_key_width - len(str(key))),
            value = format_value(mapping[key]),
        ))
    return "\n".join(lines)

def _guess_format_value(values):
    found_types = {}
    for value in values:
        found_types[type(value)] = None
        if len(found_types) > 1:
            return _repr_with_type
    found_types = found_types.keys()
    if len(found_types) != 1:
        return _repr_with_type
    elif found_types[0] in ("string", "File"):
        # For strings: omit the extra quotes and escaping. Just noise.
        # For Files: they include <TYPE path> already
        return _informative_str
    else:
        return _repr_with_type

def _maybe_sorted(container, allow_sorting = True):
    """Attempts to return the values of `container` in sorted order, if possible.

    Args:
        container: A list (or other object convertible to list)
        allow_sorting: bool; whether to sort even if it can be sorted. This
            is primarly so that callers can avoid boilerplate when they have
            a "should it be sorted" arg, but also always convert to a list.

    Returns:
        A list, in sorted order if possible, otherwise in the original order.
        This *may* be the same object as given as input.
    """
    container = _to_list(container)
    if not allow_sorting:
        return container

    if all([_is_sortable(v) for v in container]):
        return sorted(container)
    else:
        return container

def _is_sortable(obj):
    return (
        types.is_string(obj) or types.is_int(obj) or types.is_none(obj) or
        types.is_bool(obj)
    )

def _to_list(obj):
    """Attempt to convert the object to a list."""
    if types.is_string(obj):
        fail("Cannot pass string to _to_list(): {}".format(obj))
    elif types.is_list(obj):
        return obj
    elif types.is_depset(obj):
        return obj.to_list()
    else:
        fail("Unable to convert to list: {}".format(_repr_with_type(obj)))

def _match_custom(desc, func):
    """Wrap an arbitrary function up as a Matcher.

    `Match` struct attributes:
        * desc: str; a human-friendly description
        * match: callable; accepts 1 positional arg (the value to match) and
        returns bool (True if it matched, False if not).

    Args:
        desc: str; a human-friendly string describing what is matched.
        func: callable; accepts 1 positional arg (the value to match) and
            returns bool (True if it matched, False if not).
    Returns:
        a "Matcher" struct (see above).
    """
    return struct(desc = desc, match = func)

def _match_equals_wrapper(value):
    """Match that a value equals `value`, but use `value` as the `desc`.

    This is a helper so that simple equality comparisons can re-use predicate
    based APIs.

    Args:
        value: object, the value that must be equal to.

    Returns:
        `Matcher` (see `_match_custom()`), whose description is `value`.
    """
    return _match_custom(value, lambda other: other == value)

def _match_file_basename_contains(substr):
    """Match that a a `File.basename` string contains a substring.

    Args:
        substr: str; the substring to match.
    Returns:
        `Matcher` (see `_match_custom()`).
    """
    return struct(
        desc = "<basename contains '{}'>".format(substr),
        match = lambda f: substr in f.basename,
    )

def _match_file_path_matches(pattern):
    """Match that a `File.path` string matches a glob-style pattern.

    Args:
        pattern: str; the pattern to match. "*" can be used to denote
            "match anything".

    Returns:
        Match struct (see `_match_custom`).
    """
    parts = pattern.split("*")
    return struct(
        desc = "<path matches '{}'>".format(pattern),
        match = lambda f: _match_parts_in_order(f.path, parts),
    )

def _match_is_in(values):
    """Match that the to-be-matched value is in a collection of other values.

    This is equivalent to: `to_be_matched in values`. See `_match_contains`
    for the reversed operation.

    Args:
        values: The collection that the value must be within.
    Returns:
        `Matcher` (see `_match_custom()`).
    """
    return struct(
        desc = "<is any of {}>".format(repr(values)),
        match = lambda v: v in values,
    )

def _match_never(desc):
    """A matcher that never matches.

    This is mostly useful for testing, as it allows preventing any match
    while providing a custom description.

    Args:
        desc: str; human-friendly string.

    Returns:
        `Matcher` (see `_match_custom`).
    """
    return struct(
        desc = desc,
        match = lambda value: False,
    )

def _match_contains(contained):
    """Match that `contained` is within the to-be-matched value.

    This is equivalent to: `contained in to_be_matched`. See `_match_is_in`
    for the reversed operation.

    Args:
        contained: the value that to-be-matched value must contain.

    Returns:
        `Matcher` (see `_match_custom`).
    """
    return struct(
        desc = "<contains {}>".format(contained),
        match = lambda value: contained in value,
    )

def _match_str_endswith(suffix):
    """Match that a string contains another string.

    Args:
        suffix: str; the suffix that must be present

    Returns:
        `Matcher` (see `_match_custom`).
    """
    return struct(
        desc = "<endswith '{}'>".format(suffix),
        match = lambda value: value.endswith(suffix),
    )

def _match_str_matches(pattern):
    """Match that a string matches a glob-style pattern.

    Args:
        pattern: str; the pattern to match. "*" can be used to denote
            "match anything". There is an implicit "*" at the start and
            end of the pattern.

    Returns:
        Match struct (see `_match_custom`).
    """
    parts = pattern.split("*")
    return struct(
        desc = "<matches '{}'>".format(pattern),
        match = lambda value: _match_parts_in_order(value, parts),
    )

def _match_str_startswith(prefix):
    """Match that a string contains another string.

    Args:
        prefix: str; the prefix that must be present

    Returns:
        `Matcher` (see `_match_custom`).
    """
    return struct(
        desc = "<startswith '{}'>".format(prefix),
        match = lambda value: value.startswith(prefix),
    )

def _match_parts_in_order(string, parts):
    start = 0
    for part in parts:
        start = string.find(part, start)
        if start == -1:
            return False
    return True

# Rather than load many symbols, just load this symbol, and then all the
# asserts will be available.
truth = struct(
    expect = _expect,
)

# For the definition of a `Matcher` object, see `_match_custom`.
matching = struct(
    # keep sorted start
    contains = _match_contains,
    custom = _match_custom,
    equals_wrapper = _match_equals_wrapper,
    file_basename_contains = _match_file_basename_contains,
    file_path_matches = _match_file_path_matches,
    is_in = _match_is_in,
    never = _match_never,
    str_endswith = _match_str_endswith,
    str_matches = _match_str_matches,
    str_startswith = _match_str_startswith,
    # keep sorted end
)

subjects = struct(
    # keep sorted start
    bool = _bool_subject_new,
    collection = _collection_subject_new,
    depset_file = _depset_file_subject_new,
    int = _int_subject_new,
    label = _label_subject_new,
    # keep sorted end
)
