#!/bin/bash
#
# NOTE: This is meant to be run using `bazel run`. Directly running it
# won't work.
#
# Build docs for Sphinx. This is usually run by the readthedocs build process.
#
# It can also be run locally during development using Bazel, in which case,
# it will run Sphinx and start a local webserver to server HTML.
#
# To make the local devx nicer, run it using ibazel, and it will automatically
# update docs:
#   ibazel run //docs:run_sphinx_build

set -e

if [[ -z "$BUILD_WORKSPACE_DIRECTORY" ]]; then
  echo "ERROR: Must be run using bazel run"
  exit 1
fi

sphinx=$(pwd)/$1
shift

crossrefs=$1
shift

dest_dir="$BUILD_WORKSPACE_DIRECTORY/docs/source/api"
mkdir -p "$dest_dir"
for path in "$@"; do
  dest="$dest_dir/$(basename $path)"
  if [[ -e $dest ]]; then
    chmod +w $dest
  fi
  cat $path $crossrefs > $dest
done

if [[ -z "$READTHEDOCS" ]]; then
  sourcedir="$BUILD_WORKSPACE_DIRECTORY/docs/source"
  outdir="$BUILD_WORKSPACE_DIRECTORY/docs/_build"
  # This avoids stale files or since-deleted files from being processed.
  rm -fr "$outdir"
  "$sphinx" -T -b html "$sourcedir" "$outdir"

  echo "HTML built, to view, run:"
  echo "python3 -m http.server --directory $outdir"
  python3 -m http.server --directory "$outdir"
fi
