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

"""ActionSubject implementation."""

load(":collection_subject.bzl", "CollectionSubject")
load(":depset_file_subject.bzl", "DepsetFileSubject")
load(":dict_subject.bzl", "DictSubject")
load(
    ":failure_messages.bzl",
    "format_failure_missing_all_values",
    "format_failure_unexpected_value",
    "format_failure_unexpected_values",
)
load(":str_subject.bzl", "StrSubject")
load(":truth_common.bzl", "enumerate_list_as_lines", "mkmethod")

def _action_subject_new(action, meta):
    """Creates an "ActionSubject" struct.

    Method: ActionSubject.new

    Example usage:

        expect(env).that_action(action).not_contains_arg("foo")

    Args:
        action: ([`Action`]) value to check against.
        meta: ([`ExpectMeta`]) of call chain information.

    Returns:
        [`ActionSubject`] object.
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
        argv = mkmethod(self, _action_subject_argv),
        contains_at_least_args = mkmethod(self, _action_subject_contains_at_least_args),
        contains_at_least_inputs = mkmethod(self, _action_subject_contains_at_least_inputs),
        contains_flag_values = mkmethod(self, _action_subject_contains_flag_values),
        contains_none_of_flag_values = mkmethod(self, _action_subject_contains_none_of_flag_values),
        content = mkmethod(self, _action_subject_content),
        env = mkmethod(self, _action_subject_env),
        has_flags_specified = mkmethod(self, _action_subject_has_flags_specified),
        inputs = mkmethod(self, _action_subject_inputs),
        mnemonic = mkmethod(self, _action_subject_mnemonic),
        not_contains_arg = mkmethod(self, _action_subject_not_contains_arg),
        substitutions = mkmethod(self, _action_subject_substitutions),
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
    return CollectionSubject.new(
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
        args: ([`list`] of [`str`]) all the args must be in the argv exactly
            as provided. Multiplicity is respected.
    Returns
        [`Ordered`] (see `_ordered_incorrectly_new`).
    """
    return CollectionSubject.new(
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
        arg: ([`str`]) the arg that cannot be present in the argv.
    """
    if arg in self.action.argv:
        problem, actual = format_failure_unexpected_value(
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
    return DictSubject.new(
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
        flags: ([`list`] of [`str`]) The flags to check for. Include the leading "--".
            Multiplicity is respected. A flag is considered present if any of
            these forms are detected: `--flag=value`, `--flag value`, or a lone
            `--flag`.
    Returns
        [`Ordered`] (see `_ordered_incorrectly_new`).
    """
    return CollectionSubject.new(
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

    Returns:
        [`StrSubject`] object.
    """
    return StrSubject.new(
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
    return DepsetFileSubject.new(self.action.inputs, meta)

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
        flag_values: ([`list`] of ([`str`] name, [`str`]) tuples) Include the
            leading "--" in the flag name. Order and duplicates aren't checked.
            Flags without a value found use `None` as their value.
    """
    missing = []
    for flag, value in sorted(flag_values):
        if flag not in self.parsed_flags:
            missing.append("'{}' (not specified)".format(flag))
        elif value not in self.parsed_flags[flag]:
            missing.append("'{}' with value '{}'".format(flag, value))
    if not missing:
        return
    problem, actual = format_failure_missing_all_values(
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
        flag_values: ([`list`] of ([`str`] name, [`str`] value) tuples) Include
            the leading "--" in the flag name. Order and duplicates aren't
            checked.
    """
    unexpected = []
    for flag, value in sorted(flag_values):
        if flag not in self.parsed_flags:
            continue
        elif value in self.parsed_flags[flag]:
            unexpected.append("'{}' with value '{}'".format(flag, value))
    if not unexpected:
        return

    problem, actual = format_failure_unexpected_values(
        none_of = "\n" + enumerate_list_as_lines(sorted(unexpected), prefix = "  "),
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
        inputs: (collection of [`File`]) All must be present. Multiplicity
            is respected.
    Returns
        [`Ordered`] (see `_ordered_incorrectly_new`).
    """
    return DepsetFileSubject.new(
        self.action.inputs,
        meta = self.meta,
        container_name = "action inputs",
        element_plural_name = "inputs",
    ).contains_at_least(inputs)

def _action_subject_content(self):
    """Returns a `StrSubject` for `Action.content`.

    Method: ActionSubject.content

    Returns:
        [`StrSubject`] object.
    """
    return StrSubject.new(
        self.action.content,
        self.meta.derive("content()"),
    )

def _action_subject_env(self):
    """Returns a `DictSubject` for `Action.env`.

    Method: ActionSubject.env

    Args:
        self: implicitly added.
    """
    return DictSubject.new(
        self.action.env,
        self.meta.derive("env()"),
        container_name = "environment",
        key_plural_name = "envvars",
    )

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
ActionSubject = struct(
    new = _action_subject_new,
)
