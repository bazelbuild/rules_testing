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

"""# Ordered"""

# This is just a stub so doc generation is nicer.
def _ordered_in_order(self):
    """Checks that the valures were in order.

    Args:
        self: implicitly added.
    """

IN_ORDER = struct(
    in_order = _ordered_in_order,
)

def _ordered_incorrectly_new(format_problem, format_actual, meta):
    """Creates a new `Ordered` object that fails due to incorrectly ordered values.

    This creates an [`Ordered`] object that always fails. If order is correct,
    use the `_IN_ORDER` constant.

    Args:
        format_problem: (callable) accepts no args and returns string (the
            reported problem description).
        format_actual: (callable) accepts not args and returns tring (the
            reported actual description).
        meta: ([`ExpectMeta`]) used to report the failure.

    Returns:
        [`Ordered`] object.
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

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
OrderedIncorrectly = struct(
    new = _ordered_incorrectly_new,
    in_order = _ordered_incorrectly_in_order,
)
