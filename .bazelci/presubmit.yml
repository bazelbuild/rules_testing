buildifier: latest
validate_config: 1
matrix:
  platform: ["ubuntu2004", "windows", "macos"]
tasks:
  all_tests_workspace_latest:
    name: Workspace (latest Bazel)
    platform: ${{platform}}
    bazel: latest
    test_flags:
      - "--noenable_bzlmod"
      - "--enable_workspace"
    test_targets:
      - "..."
  all_tests_workspace_6.x:
    name: Workspace (Bazel 6.x)
    platform: ${{platform}}
    skip_in_bazel_downstream_pipeline: Already tested on latest
    bazel: "6.x"
    test_flags:
      - "--noenable_bzlmod"
    test_targets:
      - "//tests/..."
  all_tests_bzlmod:
    name: Bzlmod
    platform: ${{platform}}
    bazel: latest
    test_flags:
      - "--enable_bzlmod"
      - "--test_tag_filters=-skip-bzlmod,-docs"
    test_targets:
      - "..."

  docs:
    name: Docs generation
    platform: ubuntu2004
    bazel: latest
    test_flags:
      - "--enable_bzlmod"
    test_targets:
      - "//docgen/..."
      - "//docs/..."

  e2e_bzlmod:
    platform: ${{platform}}
    working_directory: e2e/bzlmod
    test_flags:
      - "--enable_bzlmod"
    test_targets:
      - "..."
