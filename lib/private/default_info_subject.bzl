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

"""# DefaultInfoSubject"""

load(":runfiles_subject.bzl", "RunfilesSubject")
load(":depset_file_subject.bzl", "DepsetFileSubject")
load(":file_subject.bzl", "FileSubject")

def _default_info_subject_new(info, *, meta):
    """Creates a `DefaultInfoSubject`

    Args:
        info: ([`DefaultInfo`]) the DefaultInfo object to wrap.
        meta: ([`ExpectMeta`]) call chain information.

    Returns:
        [`DefaultInfoSubject`] object.
    """
    self = struct(actual = info, meta = meta)
    public = struct(
        # keep sorted start
        actual = info,
        runfiles = lambda *a, **k: _default_info_subject_runfiles(self, *a, **k),
        data_runfiles = lambda *a, **k: _default_info_subject_data_runfiles(self, *a, **k),
        default_outputs = lambda *a, **k: _default_info_subject_default_outputs(self, *a, **k),
        executable = lambda *a, **k: _default_info_subject_executable(self, *a, **k),
        runfiles_manifest = lambda *a, **k: _default_info_subject_runfiles_manifest(self, *a, **k),
        # keep sorted end
    )
    return public

def _default_info_subject_runfiles(self):
    """Creates a subject for the default runfiles.

    Args:
        self: implicitly added.

    Returns:
        [`RunfilesSubject`] object
    """
    return RunfilesSubject.new(
        self.actual.default_runfiles,
        meta = self.meta.derive("runfiles()"),
        kind = "default",
    )

def _default_info_subject_data_runfiles(self):
    """Creates a subject for the data runfiles.

    Args:
        self: implicitly added.

    Returns:
        [`RunfilesSubject`] object
    """
    return RunfilesSubject.new(
        self.actual.data_runfiles,
        meta = self.meta.derive("data_runfiles()"),
        kind = "data",
    )

def _default_info_subject_default_outputs(self):
    """Creates a subject for the default outputs.

    Args:
        self: implicitly added.

    Returns:
        [`DepsetFileSubject`] object.
    """
    return DepsetFileSubject.new(
        self.actual.files,
        meta = self.meta.derive("default_outputs()"),
    )

def _default_info_subject_executable(self):
    """Creates a subject for the executable file.

    Args:
        self: implicitly added.

    Returns:
        [`FileSubject`] object.
    """
    return FileSubject.new(
        self.actual.files_to_run.executable,
        meta = self.meta.derive("executable()"),
    )

def _default_info_subject_runfiles_manifest(self):
    """Creates a subject for the runfiles manifest.

    Args:
        self: implicitly added.

    Returns:
        [`FileSubject`] object.
    """
    return FileSubject.new(
        self.actual.files_to_run.runfiles_manifest,
        meta = self.meta.derive("runfiles_manifest()"),
    )

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
DefaultInfoSubject = struct(
    # keep sorted start
    new = _default_info_subject_new,
    runfiles = _default_info_subject_runfiles,
    data_runfiles = _default_info_subject_data_runfiles,
    default_outputs = _default_info_subject_default_outputs,
    executable = _default_info_subject_executable,
    runfiles_manifest = _default_info_subject_runfiles_manifest,
    # keep sorted end
)
