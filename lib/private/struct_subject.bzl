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
"""# StructSubject

A subject for arbitrary structs. This is most useful when wrapping an ad-hoc
struct (e.g. a struct specific to a particular function). Such ad-hoc structs
are usually just plain data objects, so they don't need special functionality
that writing a full custom subject allows. If a struct would benefit from
custom accessors or asserts, write a custom subject instead.

This subject is usually used as a helper to a more formally defined subject that
knows the shape of the struct it needs to wrap. For example, a `FooInfoSubject`
implementation might use it to handle `FooInfo.struct_with_a_couple_fields`.

Note the resulting subject object is not a direct replacement for the struct
being wrapped:
    * Structs wrapped by this subject have the attributes exposed as functions,
      not as plain attributes. This matches the other subject classes and defers
      converting an attribute to a subject unless necessary.
    * The attribute name `actual` is reserved.


## Example usages

To use it as part of a custom subject returning a sub-value, construct it using
`subjects.struct()` like so:

```starlark
load("@rules_testing//lib:truth.bzl", "subjects")

def _my_subject_foo(self):
    return subjects.struct(
        self.actual.foo,
        meta = self.meta.derive("foo()"),
        attrs = dict(a=subjects.int, b=subjects.str),
    )
```

If you're checking a struct directly in a test, then you can use
`Expect.that_struct`. You'll still have to pass the `attrs` arg so it knows how
to map the attributes to the matching subject factories.

```starlark
def _foo_test(env):
    actual = env.expect.that_struct(
        struct(a=1, b="x"),
        attrs = dict(a=subjects.int, b=subjects.str)
    )
    actual.a().equals(1)
    actual.b().equals("x")
```
"""

def _struct_subject_new(actual, *, meta, attrs):
    """Creates a `StructSubject`, which is a thin wrapper around a [`struct`].

    Args:
        actual: ([`struct`]) the struct to wrap.
        meta: ([`ExpectMeta`]) object of call context information.
        attrs: ([`dict`] of [`str`] to [`callable`]) the functions to convert
            attributes to subjects. The keys are attribute names that must
            exist on `actual`. The values are functions with the signature
            `def factory(value, *, meta)`, where `value` is the actual attribute
            value of the struct, and `meta` is an [`ExpectMeta`] object.

    Returns:
        [`StructSubject`] object, which is a struct with the following shape:
          * `actual` attribute, the underlying struct that was wrapped.
          * A callable attribute for each `attrs` entry; it takes no args
            and returns what the corresponding factory from `attrs` returns.
    """
    attr_accessors = {}
    for name, factory in attrs.items():
        if not hasattr(actual, name):
            fail("Struct missing attribute: '{}' (from expression {})".format(
                name,
                meta.current_expr(),
            ))
        attr_accessors[name] = _make_attr_accessor(actual, name, factory, meta)

    public = struct(actual = actual, **attr_accessors)
    return public

def _make_attr_accessor(actual, name, factory, meta):
    # A named function is used instead of a lambda so stack traces are easier to
    # grok.
    def attr_accessor():
        return factory(getattr(actual, name), meta = meta.derive(name + "()"))

    return attr_accessor

# buildifier: disable=name-conventions
StructSubject = struct(
    # keep sorted start
    new = _struct_subject_new,
    # keep sorted end
)
