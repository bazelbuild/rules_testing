# rules_testing Changelog

## Unreleased

[0.X.0]: https://github.com/bazelbuild/rules_testing/releases/tag/v0.X.0

## Changed
* Add `{bindir}` to formatting variables.
* Format values in `ActionsSubject.contains_flag_values()`.
* `CollectionSubject` accepts new constructor parameter `format`. When used
  all asserts are formatted.
* `Actionsubjects.argv()` formats all asserts, for example
  `action.argv().contains_at_least(["-f", "{bindir}/{package}/input.txt"])`.

### Added
* Nothing yet

## [0.7.0] - 2024-10-29

[0.7.0]: https://github.com/bazelbuild/rules_testing/releases/tag/v0.7.0

### Added
* `matching.any()` and `matching.all()` for composing `Matcher` objects using
  "or" and "and" semantics, respectively
* Predicate-variants for RunfilesSubject methods:
  `RunfilesSubject.contains_exactly_predicates()`,
  `RunfilesSubject.contains_at_least_predicates()`
* `RunfilesSubject.paths()`, which returns a `CollectionSubject` of the
  runfiles paths.

## 0.6.0 - 2024-02-15

[0.6.0]: https://github.com/bazelbuild/rules_testing/releases/tag/v0.6.0

### Changed
  * `analysis_test` now only accepts keyword args. This is to enforce the
    convention that rules (or rule-like macros) have everything passed as
    keyword args.

### Added
  * Custom target under test attributes. These are like regular custom
    attributes, except they can also have their config settings changed and
    they have the usual target under test aspects applied. This allows
    testing multiple targets in one test with a mixture of configurations.
    ([#67](https://github.com/bazelbuild/rules_testing/issues/67))
  * `analysis_test` now takes the parameter `provider_subject_factories`.
    If you want to perform assertions on custom providers, you no longer need
    to use the factory parameter each time you want to retrieve the provider.
    instead, you now write `analysis_test(..., provider_subject_factories = [
    type = FooInfo, name = "FooInfo", factory = FooSubjectFactory])`.
  * Add `env.expect.that_value(Foo(...), factory=FooSubjectFactory)`.
    This allows you to do expectations on an arbitrary value of any type.

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
