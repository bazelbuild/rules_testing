# Best Practices

Here we collection tips and techniques for keeping your tests maintainable and
avoiding common pitfalls.

### Put each suite of tests in its own sub-package

It's recommended to put a given suite of unit tests in their own sub-package
(directory with a BUILD file). This is because the names of your test functions
become target names in the BUILD file, which makes it easier to create name
conflicts. By moving them into their own package, you don't have to worry about
unit test function names in one `.bzl` file conflicting with names in another.

### Give test functions private names

It's recommended to give test functions private names, i.e. start with a leading
underscore. This is because if you forget to add a test to the list of tests (an
easy mistake to make in a file with many tests), the test won't run, and it'll
appear as if everything is OK. By using a leading underscore, tools like
buildifier can detect the unused private function and will warn you that it's
unused, preventing you from accidentally forgetting it.
