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
"""# InstrumentedFilesInfoSubject"""

load(":depset_file_subject.bzl", "DepsetFileSubject")

def _instrumented_files_info_subject_new(info, *, meta):
    """Creates a subject to assert on `InstrumentedFilesInfo` providers.

    Method: InstrumentedFilesInfoSubject.new

    Args:
        info: ([`InstrumentedFilesInfo`]) provider instance.
        meta: ([`ExpectMeta`]) the meta data about the call chain.

    Returns:
        An `InstrumentedFilesInfoSubject` struct.
    """
    self = struct(
        actual = info,
        meta = meta,
    )
    public = struct(
        actual = info,
        instrumented_files = lambda *a, **k: _instrumented_files_info_subject_instrumented_files(self, *a, **k),
        metadata_files = lambda *a, **k: _instrumented_files_info_subject_metadata_files(self, *a, **k),
    )
    return public

def _instrumented_files_info_subject_instrumented_files(self):
    """Returns a `DesetFileSubject` of the instrumented files.

    Method: InstrumentedFilesInfoSubject.instrumented_files

    Args:
        self: implicitly added
    """
    return DepsetFileSubject.new(
        self.actual.instrumented_files,
        meta = self.meta.derive("instrumented_files()"),
    )

def _instrumented_files_info_subject_metadata_files(self):
    """Returns a `DesetFileSubject` of the metadata files.

    Method: InstrumentedFilesInfoSubject.metadata_files

    Args:
        self: implicitly added
    """
    return DepsetFileSubject.new(
        self.actual.metadata_files,
        meta = self.meta.derive("metadata_files()"),
    )

# We use this name so it shows up nice in docs.
# buildifier: disable=name-conventions
InstrumentedFilesInfoSubject = struct(
    new = _instrumented_files_info_subject_new,
    instrumented_files = _instrumented_files_info_subject_instrumented_files,
    metadata_files = _instrumented_files_info_subject_metadata_files,
)
