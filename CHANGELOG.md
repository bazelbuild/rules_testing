# rules_testing Changelog

## Unreleased

## [0.5.0] -  2023-10-04

[0.5.0]: https://github.com/bazelbuild/rules_testing/releases/tag/v0.5.0

### Added

  * DefaultInfoSubject for asserting the builtin DefaultInfo provider
    ([#52](https://github.com/bazelbuild/rules_testing/issues/52))
  * CollectionSubject now supports tuples.
    ([#69](https://github.com/bazelbuild/rules_testing/pull/69))

## [0.4.0] - 2023-07-10

[0.4.0]: https://github.com/bazelbuild/rules_testing/releases/tag/v0.4.0

### Added
  * Common attributes, such as `tags` and `target_compatible_with` can now
    be set on tests themselves. This allows skipping tests based on platform
    or filtering out tests using `--test_tag_filters`
    ([#43](https://github.com/bazelbuild/rules_testing/issues/43))
  * StructSubject for asserting arbitrary structs.
    ([#53](https://github.com/bazelbuild/rules_testing/issues/53))
  * (docs) Created human-friendly changelog

## [0.3.0] - 2023-07-06

### Added
  * Publically exposed subjects in `truth.bzl#subjects`. This allows
    direct creation of subjects without having to go through the
    `expect.that_*` functions. This makes it easier to implement
    custom subjects. ([#54](https://github.com/bazelbuild/rules_testing/issues/54))
  * `matching.file_basename_equals` for matching a File basename.
    ([#44](https://github.com/bazelbuild/rules_testing/issues/44))
  * `matching.file_extension_in` for matching a File extension.
    ([#44](https://github.com/bazelbuild/rules_testing/issues/44))
  * `DictSubject.get` for fetching sub-values within a dict as subjects.
    ([#51](https://github.com/bazelbuild/rules_testing/issues/51))
  * `CollectionSubject.transform` for arbitrary transforming and filtering
    of a collection.
    ([#45](https://github.com/bazelbuild/rules_testing/issues/45))

[0.3.0]: https://github.com/bazelbuild/rules_testing/releases/tag/v0.3.0

## [0.2.0] - 2023-06-14

### Added
  * Unit-test style tests. These are tests that don't require a "setup"
    phase like analysis tests do, so all you need to write is the
    implementation function that does asserts.
    ([#37](https://github.com/bazelbuild/rules_testing/issues/37))
  * (docs) Document some best practices for test naming and structure.

### Deprecated
  * `//lib:analysis_test.bzl#test_suite`: use `//lib:test_suite.bzl#test_suite`
    instead. The name in `analysis_test.bzl` will be removed in a future
    release.

[0.2.0]: https://github.com/bazelbuild/rules_testing/releases/tag/v0.2.0

## [0.1.0] - 2023-05-02

### Fixed
  * Don't require downstream user to register Python toolchains.
    ([#33](https://github.com/bazelbuild/rules_testing/issues/33))

[0.1.0]: https://github.com/bazelbuild/rules_testing/releases/tag/v0.1.0

## [0.0.5] - 2023-04-25

**NOTE: This version is broken with bzlmod**

## Fixed
  * Fix crash when equal collections with differing orders have
    `in_order()` checked.
    ([#29](https://github.com/bazelbuild/rules_testing/issues/29))

## Added
  * Generated docs with API reference at https://rules-testing.readthedocs.io
    ([#28](https://github.com/bazelbuild/rules_testing/issues/28))

[0.0.5]: https://github.com/bazelbuild/rules_testing/releases/tag/v0.0.5
