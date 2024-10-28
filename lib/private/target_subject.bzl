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

"""TargetSubject

`TargetSubject` wraps a {type}`Target` object and provides method for asserting
its state.
"""

load(
    "//lib:util.bzl",
    "TestingAspectInfo",
)
load(":action_subject.bzl", "ActionSubject")
load(":bool_subject.bzl", "BoolSubject")
load(":collection_subject.bzl", "CollectionSubject")
load(":depset_file_subject.bzl", "DepsetFileSubject")
load(":execution_info_subject.bzl", "ExecutionInfoSubject")
load(":file_subject.bzl", "FileSubject")
load(":instrumented_files_info_subject.bzl", "InstrumentedFilesInfoSubject")
load(":label_subject.bzl", "LabelSubject")
load(":run_environment_info_subject.bzl", "RunEnvironmentInfoSubject")
load(":runfiles_subject.bzl", "RunfilesSubject")
load(":truth_common.bzl", "enumerate_list_as_lines")

def _target_subject_new(target, meta):
    """Creates a subject for asserting Targets.

    Method: TargetSubject.new

    **Public attributes**:
      * `actual`: The wrapped {type}`Target` object.

    Args:
        target: {type}`Target` the target to check against.
        meta: {type}`ExpectMeta` metadata about the call chain.

    Returns:
        {type}`TargetSubject` object
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
        {type}`RunfilesSubject` object.
    """
    meta = self.meta.derive("runfiles()")
    return RunfilesSubject.new(self.target[DefaultInfo].default_runfiles, meta, "default")

def _target_subject_tags(self):
    """Gets the target's tags as a `CollectionSubject`

    Method: TargetSubject.tags

    Args:
        self: implicitly added

    Returns:
        {type}`CollectionSubject` asserting the target's tags.
    """
    return CollectionSubject.new(
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
        {type}`RunfilesSubject` object
    """
    meta = self.meta.derive("data_runfiles()")
    return RunfilesSubject.new(self.target[DefaultInfo].data_runfiles, meta, "data")

def _target_subject_default_outputs(self):
    """Creates a subject asserting on the target's default outputs.

    Method: TargetSubject.default_outputs

    Args:
        self: implicitly added.

    Returns:
        {type}`DepsetFileSubject` object.
    """
    meta = self.meta.derive("default_outputs()")
    return DepsetFileSubject.new(self.target[DefaultInfo].files, meta)

def _target_subject_executable(self):
    """Creates a subject asesrting on the target's executable File.

    Method: TargetSubject.executable

    Args:
        self: implicitly added.

    Returns:
        {type}`FileSubject` object.
    """
    meta = self.meta.derive("executable()")
    return FileSubject.new(self.target[DefaultInfo].files_to_run.executable, meta)

def _target_subject_failures(self):
    """Creates a subject asserting on the target's failure message strings.

    Method: TargetSubject.failures

    Args:
        self: implicitly added

    Returns:
        {type}`CollectionSubject[str]`
    """
    meta = self.meta.derive("failures()")
    if AnalysisFailureInfo in self.target:
        failure_messages = sorted([
            f.message
            for f in self.target[AnalysisFailureInfo].causes.to_list()
        ])
    else:
        failure_messages = []
    return CollectionSubject.new(failure_messages, meta, container_name = "failure messages")

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
        "expected to have provider: {}".format(_provider_subject_factory(self, provider).name),
        "but provider was not found",
    )

def _target_subject_label(self):
    """Returns a `LabelSubject` for the target's label value.

    Method: TargetSubject.label
    """
    return LabelSubject.new(
        label = self.target.label,
        meta = self.meta.derive(expr = "label()"),
    )

def _target_subject_output_group(self, name):
    """Returns a DepsetFileSubject of the files in the named output group.

    Method: TargetSubject.output_group

    Args:
        self: implicitly added.
        name: {type}`str` an output group name. If it isn't present, an error is raised.

    Returns:
        DepsetFileSubject of the named output group.
    """
    info = self.target[OutputGroupInfo]
    if not hasattr(info, name):
        fail("OutputGroupInfo.{} not present for target {}".format(name, self.target.label))
    return DepsetFileSubject.new(
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
            Additional types of providers can be pre-registered by using the
            `provider_subject_factories` arg of `analysis_test`.

    Returns:
        A subject wrapper of the provider value.
    """
    if factory:
        provider_subject_factory = struct(
            type = provider_key,
            # str(provider_key) just returns "<provider>", which isn't helpful.
            # For lack of a better option, just call it unknown
            name = "<Unknown provider>",
            factory = factory,
        )
    else:
        provider_subject_factory = _provider_subject_factory(self, provider_key)

    if not provider_subject_factory.factory:
        fail("Unsupported provider: {}".format(provider_subject_factory.name))
    info = self.target[provider_key]

    return provider_subject_factory.factory(
        info,
        meta = self.meta.derive("provider({})".format(provider_subject_factory.name)),
    )

def _target_subject_action_generating(self, short_path):
    """Get the single action generating the given path.

    Method: TargetSubject.action_generating

    NOTE: in order to use this method, the target must have the `TestingAspectInfo`
    provider (added by the `testing_aspect` aspect.)

    Args:
        self: implicitly added.
        short_path: {type}`str` the output's short_path to match. The value is
            formatted using {obj}`format_str`, so its template keywords can be
            directly passed.

    Returns:
        {type}`ActionSubject` for the matching action. If no action is found, or
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
    return ActionSubject.new(action, meta)

def _target_subject_action_named(self, mnemonic):
    """Get the single action with the matching mnemonic.

    Method: TargetSubject.action_named

    NOTE: in order to use this method, the target must have the {obj}`TestingAspectInfo`
    provider (added by the {obj}`testing_aspect`] aspect.)

    Args:
        self: implicitly added.
        mnemonic: {type}`str` the mnemonic to match

    Returns:
        {type}`ActionSubject`. If no action matches, or more than one action matches, an error
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
                found = enumerate_list_as_lines([
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
    return ActionSubject.new(action, meta)

# NOTE: This map should only have attributes that are common to all target
# types, otherwise we can't rely on an attribute having a specific type.
_ATTR_NAME_TO_SUBJECT_FACTORY = {
    "testonly": BoolSubject.new,
}

def _target_subject_attr(self, name, *, factory = None):
    """Gets a subject-wrapped value for the named attribute.

    Method: TargetSubject.attr

    NOTE: in order to use this method, the target must have the `TestingAspectInfo`
    provider (added by the `testing_aspect` aspect.)

    Args:
        self: implicitly added
        name: {type}`str` the attribute to get. If it's an unsupported attribute, and
            no explicit factory was provided, an error will be raised.
        factory: {type}`callable` function to create the returned subject based on
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

def _provider_subject_factory(self, provider):
    for provider_subject_factory in self.meta.env.provider_subject_factories:
        if provider_subject_factory.type == provider:
            return provider_subject_factory

    return struct(
        type = provider,
        name = "<Unknown provider>",
        factory = None,
    )

# Providers aren't hashable, so we have to use a list of structs.
PROVIDER_SUBJECT_FACTORIES = [
    struct(
        type = InstrumentedFilesInfo,
        name = "InstrumentedFilesInfo",
        factory = InstrumentedFilesInfoSubject.new,
    ),
    struct(
        type = RunEnvironmentInfo,
        name = "RunEnvironmentInfo",
        factory = RunEnvironmentInfoSubject.new,
    ),
    struct(
        type = testing.ExecutionInfo,
        name = "testing.ExecutionInfo",
        factory = ExecutionInfoSubject.new,
    ),
]

def _target_subject_typedef():
    """Subject for `Target` objects.

    :::{field} actual
    :type: Target

    Underlying object asserted against.
    :::
    """

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
TargetSubject = struct(
    TYPEDEF = _target_subject_typedef,
    new = _target_subject_new,
    runfiles = _target_subject_runfiles,
    tags = _target_subject_tags,
    get_attr = _target_subject_get_attr,
    data_runfiles = _target_subject_data_runfiles,
    default_outputs = _target_subject_default_outputs,
    executable = _target_subject_executable,
    failures = _target_subject_failures,
    has_provider = _target_subject_has_provider,
    label = _target_subject_label,
    output_group = _target_subject_output_group,
    provider = _target_subject_provider,
    action_generating = _target_subject_action_generating,
    action_named = _target_subject_action_named,
    attr = _target_subject_attr,
)
