"""Shared private utilities."""

def _do_nothing_impl(ctx):
    _ = ctx  # @unused
    return []

do_nothing = rule(implementation = _do_nothing_impl)

def get_test_name_from_function(func):
    """Derives a suitable test name from a function.

    This can be used for better test feedback.

    Args:
      func: (callable) A test implementation or setup function.

    Returns:
      (str) The name of the given function, suitable as a test name.
    """

    # Starlark currently stringifies a function as "<function NAME>", so we use
    # that knowledge to parse the "NAME" portion out. If this behavior ever
    # changes, we'll need to update this.
    # TODO(bazel-team): Expose a ._name field on functions to avoid this.
    func_name = str(func)
    func_name = func_name.partition("<function ")[-1]
    func_name = func_name.rpartition(">")[0]
    func_name = func_name.partition(" ")[0]

    # Strip leading/trailing underscores so that test functions can
    # have private names. This better allows unused tests to be flagged by
    # buildifier (indicating a bug or code to delete)
    return func_name.strip("_")
