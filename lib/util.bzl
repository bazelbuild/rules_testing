"""Various utilities to aid with testing."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:types.bzl", "types")

# TODO(ilist): remove references to skylib analysistest
load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("@bazel_skylib//rules:write_file.bzl", "write_file")

# We add the manual tag to prevent implicitly building and running the subject
# targets. When the rule-under-test is a test rule, it prevents trying to run
# it. For binary rules, it prevents implicitly building it (and thus activating
# more validation logic) when --build_tests_only is enabled.
PREVENT_IMPLICIT_BUILDING_TAGS = [
    "manual",  # Prevent `bazel ...` from directly building them
]
PREVENT_IMPLICIT_BUILDING = {"tags": PREVENT_IMPLICIT_BUILDING_TAGS}

def merge_kwargs(*kwargs):
    """Merges multiple dicts of kwargs.

    This is similar to dict.update except:
        * If a key's value is a list, it'll be concatenated to any existing value.
        * An error is raised when the same non-list key occurs more than once.

    Args:
        *kwargs: kwarg arg dicts to merge

    Returns:
        dict of the merged kwarg dics.
    """
    final = {}
    for kwarg in kwargs:
        for key, value in kwarg.items():
            if types.is_list(value):
                final[key] = final.get(key, []) + value
            elif key in final:
                fail("Key already exists: {}: {}".format(key, final[key]))
            else:
                final[key] = value
    return final

def empty_file(name):
    """Generates an empty file and returns the target name for it.

    Args:
        name: str, name of the generated output file.

    Returns:
        str, the name of the generated output.
    """
    write_file(
        name = "write_" + name,
        content = [],
        out = name,
    )
    return name

def helper_target(rule, **kwargs):
    """Define a target only used as a Starlark test input.

    This is useful for e.g. analysis tests, which have to setup a small
    graph of targets that should only be built via the test (e.g. they
    may require config settings the test sets). Tags are added to
    hide the target from `:all`, `/...`, TAP, etc.

    Args:
        rule: rule-like function.
        **kwargs: Any kwargs to pass to `rule`. Additional tags will
            be added to hide the target.
    """
    kwargs = merge_kwargs(kwargs, PREVENT_IMPLICIT_BUILDING)
    rule(**kwargs)

def short_paths(files_depset):
    """Returns the `short_path` paths for a depset of files."""
    return [f.short_path for f in files_depset.to_list()]

def runfiles_paths(workspace_name, runfiles):
    """Returns the root-relative short paths for the files in runfiles.

    Args:
        workspace_name: str, the workspace name (`ctx.workspace_name`).
        runfiles: runfiles, the runfiles to convert to short paths.

    Returns:
        list of short paths but runfiles root-relative. e.g.
        'myworkspace/foo/bar.py'.
    """
    paths = []
    paths.extend(short_paths(runfiles.files))
    paths.extend(runfiles.empty_filenames.to_list())
    paths.extend(_runfiles_symlink_paths(runfiles.symlinks))
    paths = _prepend_path(workspace_name, paths)

    paths.extend(_runfiles_symlink_paths(runfiles.root_symlinks))
    return paths

def runfiles_map(workspace_name, runfiles):
    """Convert runfiles to a path->file mapping.

    This approximates how Bazel materializes the runfiles on the file
    system.

    Args:
        workspace_name: str; the workspace the runfiles belong to.
        runfiles: runfiles; the runfiles to convert to a map.

    Returns:
        `dict[str, optional File]` that maps the path under the runfiles root
        to it's backing file. The file may be None if the path came
        from `runfiles.empty_filenames`.
    """
    path_map = {}
    workspace_prefix = workspace_name + "/"
    for file in runfiles.files.to_list():
        path_map[workspace_prefix + file.short_path] = file
    for path in runfiles.empty_filenames.to_list():
        path_map[workspace_prefix + path] = None

    # NOTE: What happens when different files have the same symlink isn't
    # exactly clear. For lack of a better option, we'll just take the last seen
    # value.
    for entry in runfiles.symlinks.to_list():
        path_map[workspace_prefix + entry.path] = entry.target_file
    for entry in runfiles.root_symlinks.to_list():
        path_map[entry.path] = entry.target_file
    return path_map

def _prepend_path(prefix, path_strs):
    return [paths.join(prefix, p) for p in path_strs]

def _runfiles_symlink_paths(symlinks_depset):
    return [entry.path for entry in symlinks_depset.to_list()]

TestingAspectInfo = provider(
    "Details about a target-under-test useful for testing.",
    fields = {
        "attrs": "The raw attributes of the target under test.",
        "actions": "The actions registered for the target under test.",
        "vars": "The var dict (ctx.var) for the target under text.",
        "bin_path": "str; the ctx.bin_dir.path value (aka execroot).",
    },
)

def _testing_aspect_impl(target, ctx):
    return [TestingAspectInfo(
        attrs = ctx.rule.attr,
        actions = target.actions,
        vars = ctx.var,
        bin_path = ctx.bin_dir.path,
    )]

# TODO(ilist): make private, after switching python tests to new testing framework
testing_aspect = aspect(
    implementation = _testing_aspect_impl,
)

# The same as `testing_aspect`, but recurses through all attributes in the
# whole graph. This is useful if you need to extract information about
# targets that aren't direct dependencies of the target under test, or to
# reconstruct a more complete graph of inputs/outputs/generating-target.
# TODO(ilist): make private, after switching python tests to new testing framework
recursive_testing_aspect = aspect(
    implementation = _testing_aspect_impl,
    attr_aspects = ["*"],
)

def get_target_attrs(env):
    return analysistest.target_under_test(env)[TestingAspectInfo].attrs

# TODO(b/203567235): Remove this after cl/382467002 lands and the regular
# `analysistest.target_actions()` can be used.
def get_target_actions(env):
    return analysistest.target_under_test(env)[TestingAspectInfo].actions

def is_runfiles(obj):
    """Tells if an object is a runfiles object."""
    return type(obj) == "runfiles"

def is_file(obj):
    """Tells if an object is a File object."""
    return type(obj) == "File"

def skip_test(name):
    """Defines a test target that is always skipped.

    This is useful for tests that should be skipped if some condition,
    determinable during the loading phase, isn't met. The resulting target will
    show up as "SKIPPED" in the output.

    If possible, prefer to use `target_compatible_with` to mark tests as
    incompatible. This avoids confusing behavior where the type of a target
    varies depending on loading-phase behavior.

    Args:
      name: The name of the target.
    """
    _skip_test(
        name = name,
        target_compatible_with = ["//third_party/bazel_platforms:incompatible"],
        tags = ["notap"],
    )

def _skip_test_impl(ctx):
    fail("Should have been skipped")

_skip_test = rule(
    implementation = _skip_test_impl,
    test = True,
)

def _force_exec_config_impl(ctx):
    return [DefaultInfo(
        files = depset(ctx.files.tools),
        default_runfiles = ctx.runfiles().merge_all([
            t[DefaultInfo].default_runfiles
            for t in ctx.attr.tools
        ]),
        data_runfiles = ctx.runfiles().merge_all([
            t[DefaultInfo].data_runfiles
            for t in ctx.attr.tools
        ]),
    )]

force_exec_config = rule(
    implementation = _force_exec_config_impl,
    doc = "Rule to force arbitrary targets to `cfg=exec` so they can be " +
          "tested when used as tools.",
    attrs = {
        "tools": attr.label_list(
            cfg = "exec",
            allow_files = True,
            doc = "A list of tools to force into the exec config",
        ),
    },
)

util = struct(
    # keep sorted start
    empty_file = empty_file,
    force_exec_config = force_exec_config,
    helper_target = helper_target,
    merge_kwargs = merge_kwargs,
    recursive_testing_aspect = recursive_testing_aspect,
    runfiles_map = runfiles_map,
    runfiles_paths = runfiles_paths,
    short_paths = short_paths,
    skip_test = skip_test,
    testing_aspect = testing_aspect,
    # keep sorted end
)
