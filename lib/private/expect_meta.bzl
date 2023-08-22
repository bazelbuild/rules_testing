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
"""# ExpectMeta

ExpectMeta object implementation.
"""

load("@bazel_skylib//lib:unittest.bzl", ut_asserts = "asserts")

def _expect_meta_new(env, exprs = [], details = [], format_str_kwargs = None):
    """Creates a new "ExpectMeta" struct".

    Method: ExpectMeta.new

    ExpectMeta objects are internal helpers for the Expect object and Subject
    objects. They are used for Subjects to store and communicate state through a
    series of call chains and asserts.

    This constructor should only be directly called by `Expect` objects. When a
    parent Subject is creating a child-Subject, then [`derive()`] should be
    used.

    ### Env objects

    The `env` object basically provides a way to interact with things outside
    of the truth assertions framework. This allows easier testing of the
    framework itself and decouples it from a particular test framework (which
    makes it usable by by rules_testing's analysis_test and skylib's
    analysistest)

    The `env` object requires the following attribute:
      * ctx: The test's ctx.

    The `env` object allows the following attributes to customize behavior:
      * fail: A callable that accepts a single string, which is the failure
        message. Its return value is ignored. This is called when an assertion
        fails. It's generally expected that it records a failure instead of
        immediately failing.
      * has_provider: (callable) it accepts two positional args, target and
        provider and returns [`bool`]. This is used to implement `Provider in
        target` operations.
      * get_provider: (callable) it accepts two positional args, target and
        provider and returns the provider value. This is used to implement
        `target[Provider]`.

    Args:
        env: unittest env struct or some approximation.
        exprs: ([`list`] of [`str`]) the expression strings of the call chain for
            the subject.
        details: ([`list`] of [`str`]) additional details to print on error. These
            are usually informative details of the objects under test.
        format_str_kwargs: optional dict of format() kwargs. These kwargs
            are propagated through `derive()` calls and used when
            `ExpectMeta.format_str()` is called.

    Returns:
        [`ExpectMeta`] object.
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
        current_expr = lambda *a, **k: _expect_meta_current_expr(self, *a, **k),
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
        expr: ([`str`]) human-friendly description of the call chain expression.
            e.g., if `foo_subject.bar_named("baz")` returns a child-subject,
            then "bar_named("bar")" would be the expression.
        details: (optional [`list`] of [`str`]) human-friendly descriptions of additional
            detail to include in errors. This is usually additional information
            the child Subject wouldn't include itself. e.g. if
            `foo.first_action_argv().contains(1)`, returned a ListSubject, then
            including "first action: Action FooCompile" helps add context to the
            error message. If there is no additional detail to include, pass
            None.
        format_str_kwargs: ([`dict`] of format()-kwargs) additional kwargs to
            make available to [`format_str`] calls.

    Returns:
        [`ExpectMeta`] object.
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
        template: ([`str`]) the format template string to use.

    Returns:
        [`str`]; the template with parameters replaced.
    """
    return template.format(**self._format_str_kwargs)

def _expect_meta_get_provider(self, target, provider):
    """Get a provider from a target.

    This is equivalent to `target[provider]`; the extra level of indirection
    is to aid testing.

    Args:
        self: implicitly added.
        target: ([`Target`]) the target to get the provider from.
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
        target: ([`Target`]) the target to check for the provider.
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
        problem: ([`str`]) a string describing the expected value or problem
            detected, and the expected values that weren't satisfied. A colon
            should be used to separate the description from the values.
            The description should be brief and include the word "expected",
            e.g. "expected: foo", or "expected values missing: <list of missing>",
            the key point being the reader can easily take the values shown
            and look for it in the actual values displayed below it.
        actual: ([`str`]) a string describing the values observed. A colon should
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
        details = "where... (most recent context last)\n" + details
    msg = """\
in test: {test}
value of: {expr}
{problem}
{actual}
{details}
""".format(
        test = self.ctx.label,
        expr = _expect_meta_current_expr(self),
        problem = problem,
        actual = actual,
        details = details,
    )
    _expect_meta_call_fail(self, msg)

def _expect_meta_current_expr(self):
    """Get a string representing the current expression.

    Args:
        self: implicitly added.

    Returns:
        [`str`] A string representing the current expression, e.g.
        "foo.bar(something).baz()"
    """
    return ".".join(self._exprs)

def _expect_meta_call_fail(self, msg):
    """Adds a failure to the test run.

    Args:
        self: implicitly added.
        msg: ([`str`]) the failure message.
    """
    fail_func = getattr(self.env, "fail", None)
    if fail_func != None:
        fail_func(msg)
    else:
        # Add a leading newline because unittest prepends the repr() of the
        # function under test, which is often long and uninformative, making
        # the first line of our message hard to see.
        ut_asserts.true(self.env, False, "\n" + msg)

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
ExpectMeta = struct(
    new = _expect_meta_new,
    derive = _expect_meta_derive,
    format_str = _expect_meta_format_str,
    get_provider = _expect_meta_get_provider,
    has_provider = _expect_meta_has_provider,
    add_failure = _expect_meta_add_failure,
    call_fail = _expect_meta_call_fail,
)
