"""Common code used by truth."""

load("@bazel_skylib//lib:types.bzl", "types")

def mkmethod(self, method):
    """Bind a struct as the first arg to a function.

    This is loosely equivalent to creating a bound method of a class.
    """
    return lambda *args, **kwargs: method(self, *args, **kwargs)

def repr_with_type(value):
    return "<{} {}>".format(type(value), repr(value))

def _informative_str(value):
    value_str = str(value)
    if not value_str:
        return "<empty string ∅>"
    elif value_str != value_str.strip():
        return '"{}" <sans quotes; note whitespace within>'.format(value_str)
    else:
        return value_str

def enumerate_list_as_lines(values, prefix = "", format_value = None):
    """Format a list of values in a human-friendly list.

    Args:
        values: ([`list`]) the values to display, one per line.
        prefix: ([`str`]) prefix to add before each line item.
        format_value: optional callable to convert each value to a string.
            If not specified, then an appropriate converter will be inferred
            based on the values. If specified, then the callable must accept
            1 positional arg and return a string.

    Returns:
        [`str`]; the values formatted as a human-friendly list.
    """
    if not values:
        return "{}<empty>".format(prefix)

    if format_value == None:
        format_value = guess_format_value(values)

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

def guess_format_value(values):
    """Guess an appropriate human-friendly formatter to use with the value.

    Args:
        values: The object to pick a formatter for.

    Returns:
        callable that accepts the value.
    """
    found_types = {}
    for value in values:
        found_types[type(value)] = None
        if len(found_types) > 1:
            return repr_with_type
    found_types = found_types.keys()
    if len(found_types) != 1:
        return repr_with_type
    elif found_types[0] in ("string", "File"):
        # For strings: omit the extra quotes and escaping. Just noise.
        # For Files: they include <TYPE path> already
        return _informative_str
    else:
        return repr_with_type

def maybe_sorted(container, allow_sorting = True):
    """Attempts to return the values of `container` in sorted order, if possible.

    Args:
        container: ([`list`] | (or other object convertible to list))
        allow_sorting: ([`bool`]) whether to sort even if it can be sorted. This
            is primarly so that callers can avoid boilerplate when they have
            a "should it be sorted" arg, but also always convert to a list.

    Returns:
        A list, in sorted order if possible, otherwise in the original order.
        This *may* be the same object as given as input.
    """
    container = to_list(container)
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

def to_list(obj):
    """Attempt to convert the object to a list, else error.

    NOTE: This only supports objects that are typically understood as
    lists, not any iterable. Types like `dict` and `str` are iterable,
    but will be rejected.

    Args:
        obj: ([`list`] | [`depset`]) The object to convert to a list.

    Returns:
        [`list`] of the object
    """
    if types.is_string(obj):
        fail("Cannot pass string to to_list(): {}".format(obj))
    elif types.is_list(obj):
        return obj
    elif types.is_depset(obj):
        return obj.to_list()
    else:
        fail("Unable to convert to list: {}".format(repr_with_type(obj)))
