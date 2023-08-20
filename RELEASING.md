# Releases

Releases are mostly automated and triggered by adding a tag:

Assuming you have a remote named `upstream` pointing to the repo:

* `git tag v<VERSION> upstream/master && git push upstream --tags`

After pushing, the release action will trigger. It will package it up, create a
release on the GitHub release page, and trigger an update to the Bazel Central
Registry (BCR).
