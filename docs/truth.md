# Truth Guide

Also see: [Truth API reference](api/truth.md)

## What is Truth?

Truth is a style of doing asserts that makes it easy to perform complex
assertions that are easy to understand and give actionable error messages.

The basic way it works is wrapping a value in a type-specific object that
provides type-specific assertion methods. This style provides several benefits:

* A fluent API that more directly expresses the assertion
* More egonomic assert functions
* Error messages with more informative context
* Promotes code reuses at the type-level.

## Example Usage

Note that all examples assume usage of the rules_testing `analysis_test`
framework, but truth itself does not require it.

```
def test_foo(env, target):
    subject = env.expect.that_target(target)
    subject.runfiles().contains_at_least(["foo.txt"])
    subject.executable().equals("bar.exe")

    subject = env.expect.that_action(...)
    subject.contains_at_least_args(...)
```

## Subjects

Subjects are wrappers around a value that provide ways to assert on the value,
access sub-values of it, or otherwise augment interacting with the wrapped
value. For example, `TargetSubject` wraps Bazel `Target` objects and
`RunfilesSubject` wraps Bazel `runfiles` objects. Normally accessing a target's
runfiles and verifying the runfiles contents would require the verbose
`target[DefaultInfo].default_runfiles`, plus additional code to convert a
`runfiles` object's `files`, `symlinks`, `root_symlinks`, and `empty_filenames`
into a single list to verify. With subject classes, however, it can be concisely
expressed as `expect.that_target(target).runfiles().contains(path)`.

The Truth library provides subjects for types that are built into Bazel, but
custom subjects can be implemented to handle custom providers or other objects.

## Predicates

Because Starlark's data model doesn't allow customizing equality checking, some
subjects allow matching values by using a predicate function. This makes it
easier to, for example, ignore a platform-specific file extension.

This is implemented using the structural `Matcher` "interface". This is a struct
that contains the predicate function and a description of what the function
does, which allows for more intelligible error messages.

A variety of matchers are in `truth.bzl#matching`, but custom matches can be
implemented using `matching.custom_matcher`

## Writing a new Subject

Writing a new Subject involves two basic pieces:

1.  Creating a constructor function, e.g. `_foo_subject_new`, that takes the
    actual value and an `ExpectMeta` object (see `_expect_meta_new()`).

2.  Adding a method to `expect` or another Subject class to pass along state and
    instantiate the new subject; both may be modified if the actual object can
    be independenly created or obtained through another subject.

    For top-level subjects, a method named `that_foo()` should be added to the
    `expect` class.

    For child-subjects, an appropriately named method should be added to the
    parent subject, and the parent subject should call `ExpectMeta.derive()` to
    create a new set of meta data for the child subject.

The assert methods a subject provides are up to the subject, but try to follow
the naming scheme of other subjects. The purpose of a custom subject is to make
it easier to write tests that are correct and informative. It's common to have a
combination of ergonomic asserts for common cases, and delegating to
child-subjects for other cases.

## Adding asserts to a subject

Fundamentally, an assert method calls `ExpectMeta.add_failure()` to record when
there is a failure. That method will wire together any surrounding context with
the provided error message information. Otherwise an assertion is free to
implement checks how it pleases.

The naming of functions should mostly read naturally, but doesn't need to be
perfect grammatically. Be aware of ambiguous words like "contains" or "matches".
For example, `contains_flag("--foo")` -- does this check that "--flag" was
specified at all (ignoring value), or that it was specified and has no value?

Assertion functions can make use of a variety of helper methods in processing
values, comparing them, and generating error messages. Helpers of particular
note are:

* `_check_*`: These functions implement comparison, error formatting, and
  error reporting.
* `_compare_*`: These functions implements comparison for different cases
  and take care of various edge cases.
* `_format_failure_*`: These functions create human-friendly messages
  describing both the observed values and the problem with them.
* `_format_problem_*`: These functions format only the problem identified.
* `_format_actual_*`: These functions format only the observed values.
