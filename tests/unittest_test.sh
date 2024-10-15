#!/usr/bin/env bash

# Copyright 2019 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# End to end tests for unittest.bzl.
#
# Specifically, end to end tests of unittest.bzl cover verification that
# analysis-phase tests written with unittest.bzl appropriately
# cause test failures in cases where violated assertions are made.

# --- begin runfiles.bash initialization ---
set -euo pipefail
 if [[ -f "$TEST_SRCDIR/MANIFEST" ]]; then
    export RUNFILES_MANIFEST_FILE="$TEST_SRCDIR/MANIFEST"
    fi
if [[ ! -d "${RUNFILES_DIR:-/dev/null}" && ! -f "${TEST_SRCDIR:-/dev/null}/MANIFEST" ]]; then
  if [[ -f "$TEST_SRCDIR/MANIFEST" ]]; then
    export RUNFILES_MANIFEST_FILE="$TEST_SRCDIR/MANIFEST"
  elif [[ -f "$0.runfiles/MANIFEST" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles/MANIFEST"
  elif [[ -f "$TEST_SRCDIR/io_bazel/tools/bash/runfiles/runfiles.bash" ]]; then
    export RUNFILES_DIR="$TEST_SRCDIR"
  fi
fi
if [[ -f "${RUNFILES_DIR:-/dev/null}/io_bazel/tools/bash/runfiles/runfiles.bash" ]]; then
  source "${RUNFILES_DIR}/io_bazel/tools/bash/runfiles/runfiles.bash"
elif [[ -f "${TEST_SRCDIR:-/dev/null}/MANIFEST" ]]; then
  source "$(grep -m1 "^io_bazel/tools/bash/runfiles/runfiles.bash " \
            "$RUNFILES_MANIFEST_FILE" | cut -d ' ' -f 2-)"
else
  echo >&2 "ERROR: cannot find //third_party/bazel/tools/bash/runfiles:runfiles.bash"
  exit 1
fi
# --- end runfiles.bash initialization ---

source "$(rlocation $TEST_WORKSPACE/bazel/src/test/shell/unittest.bash)" \
  || { echo "Could not source bazel/src/test/shell/unittest.bash" >&2; exit 1; }

function create_pkg() {
  local -r pkg="$1"
  mkdir -p "$pkg"
  cd "$pkg"

  cat > WORKSPACE <<EOF
workspace(name = 'rules_testing')

load("//third_party/bazel_rules/rules_testing/lib:unittest.bzl", "register_unittest_toolchains")

register_unittest_toolchains()
EOF


  mkdir -p third_party/bazel_platforms/os
  cat > third_party/bazel_platforms/os/BUILD <<EOF
constraint_setting(name = "os")

constraint_value(
    name = "linux",
    constraint_setting = ":os",
    visibility = ["//visibility:public"],
)

constraint_value(
    name = "windows",
    constraint_setting = ":os",
    visibility = ["//visibility:public"],
)
EOF
  # Copy relevant skylib sources into the current workspace. 
  saved_pwd="$(pwd)"
  mkdir -p third_party/bazel_skylib

  mkdir -p third_party/bazel_skylib/lib
  touch third_party/bazel_skylib/lib/BUILD
  cat > third_party/bazel_skylib/lib/BUILD <<EOF
exports_files(["*.bzl"])
EOF
  ln -sf "$(rlocation $TEST_WORKSPACE/third_party/bazel_skylib/lib/dicts.bzl)" third_party/bazel_skylib/lib/dicts.bzl
  ln -sf "$(rlocation $TEST_WORKSPACE/third_party/bazel_skylib/lib/new_sets.bzl)" third_party/bazel_skylib/lib/new_sets.bzl
  ln -sf "$(rlocation $TEST_WORKSPACE/third_party/bazel_skylib/lib/partial.bzl)" third_party/bazel_skylib/lib/partial.bzl
  ln -sf "$(rlocation $TEST_WORKSPACE/third_party/bazel_skylib/lib/sets.bzl)" third_party/bazel_skylib/lib/sets.bzl
  ln -sf "$(rlocation $TEST_WORKSPACE/third_party/bazel_skylib/lib/types.bzl)" third_party/bazel_skylib/lib/types.bzl


  mkdir -p third_party/bazel_rules/rules_testing
  cd third_party/bazel_rules/rules_testing
  # Copy relevant rules_testing sources into the current workspace.

  mkdir -p tests
  touch tests/BUILD
  cat > tests/BUILD <<EOF
exports_files(["*.bzl"])
EOF
  ln -sf "$(rlocation $TEST_WORKSPACE/third_party/bazel_rules/rules_testing/tests/unittest_tests.bzl)" tests/unittest_tests.bzl

  mkdir -p lib
  touch lib/BUILD
  cat > lib/BUILD <<EOF
exports_files(["*.bzl"])
EOF
  ln -sf "$(rlocation $TEST_WORKSPACE/third_party/bazel_rules/rules_testing/lib/unittest.bzl)" lib/unittest.bzl

  # Remove `package(default_applicable_license = ...)` line to avoid depending on rules_license inside this test
  sed -e '/package(default_applicable_licenses = .*)/d' \

  mkdir -p tests/unittest_toolchains
  ln -sf "$(rlocation $TEST_WORKSPACE/third_party/bazel_rules/rules_testing/tests/unittest_toolchains/BUILD)" tests/unittest_toolchains/BUILD

  # Create test files
  cd $saved_pwd
  mkdir -p testdir
  cat > testdir/BUILD <<'EOF'
load("//third_party/bazel_rules/rules_testing/tests:unittest_tests.bzl",
    "basic_passing_test",
    "basic_failing_test",
    "failure_message_test",
    "fail_unexpected_passing_test",
    "fail_unexpected_passing_fake_rule")

basic_passing_test(name = "basic_passing_test")

basic_failing_test(name = "basic_failing_test")

failure_message_test(
    name = "shell_escape_failure_message_test",
    message = "Contains $FOO",
)

failure_message_test(
   name = "cmd_escape_failure_message_test",
   message = "Contains %FOO%",
)

failure_message_test(
   name = "eof_failure_message_test",
   message = "\nEOF\n more after EOF",
)

fail_unexpected_passing_test(
    name = "fail_unexpected_passing_test",
    target_under_test = ":fail_unexpected_passing_fake_target",
)

fail_unexpected_passing_fake_rule(
    name = "fail_unexpected_passing_fake_target",
    tags = ["manual"])
EOF
}

function test_basic_passing_test() {
  local -r pkg="${FUNCNAME[0]}"
  create_pkg "$pkg"

  bazel test -s --verbose_failures --experimental_split_xml_generation=false testdir:basic_passing_test >"$TEST_log" 2>&1 || fail "Expected test to pass"

  expect_log "PASSED"
}

function test_basic_failing_test() {
  local -r pkg="${FUNCNAME[0]}"
  create_pkg "$pkg"

  bazel test testdir:basic_failing_test --test_output=all --verbose_failures \
      >"$TEST_log" 2>&1 && fail "Expected test to fail" || true

  expect_log "In test _basic_failing_test from //third_party/bazel_rules/rules_testing/tests:unittest_tests.bzl: Expected \"1\", but got \"2\""
}

function test_shell_escape_failure_message_test() {
  local -r pkg="${FUNCNAME[0]}"
  create_pkg "$pkg"

  bazel test testdir:shell_escape_failure_message_test --test_output=all --verbose_failures \
      >"$TEST_log" 2>&1 && fail "Expected test to fail" || true

  expect_log 'In test _failure_message_test from //third_party/bazel_rules/rules_testing/tests:unittest_tests.bzl: Expected "", but got "Contains $FOO"'
}

function test_cmd_escape_failure_message_test() {
  local -r pkg="${FUNCNAME[0]}"
  create_pkg "$pkg"

  bazel test testdir:cmd_escape_failure_message_test --test_output=all --verbose_failures \
      >"$TEST_log" 2>&1 && fail "Expected test to fail" || true

  expect_log 'In test _failure_message_test from //third_party/bazel_rules/rules_testing/tests:unittest_tests.bzl: Expected "", but got "Contains %FOO%"'
}

function test_eof_failure_message_test() {
  local -r pkg="${FUNCNAME[0]}"
  create_pkg "$pkg"

  bazel test testdir:eof_failure_message_test --test_output=all --verbose_failures \
      >"$TEST_log" 2>&1 && fail "Expected test to fail" || true

  expect_log '^ more after EOF'
}

function test_fail_unexpected_passing_test() {
  local -r pkg="${FUNCNAME[0]}"
  create_pkg "$pkg"

  bazel test testdir:fail_unexpected_passing_test --test_output=all --verbose_failures \
      >"$TEST_log" 2>&1 && fail "Expected test to fail" || true

  expect_log "Expected failure of target_under_test, but found success"
}

cd "$TEST_TMPDIR"
run_suite "unittest test suite"