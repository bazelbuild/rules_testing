#!/bin/bash
#
# NOTE: This is meant to be run using `bazel run`. Directly running it
# won't work.
#
# Build docs for Sphinx. This is usually run by the readthedocs build process.
#
# It can also be run locally during development using Bazel.
#
# To make the local devx nicer, run it using ibazel, and it will automatically
# re-run sphinx.

set -x
set -e

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
  rm -fr $BUILD_WORKSPACE_DIRECTORY/docs/build
  cd $BUILD_WORKSPACE_DIRECTORY/docs/source
  sourcedir=$BUILD_WORKSPACE_DIRECTORY/docs/source
  outdir=$BUILD_WORKSPACE_DIRECTORY/docs/build
  doctrees=$BUILD_WORKSPACE_DIRECTORY/docs/build/doctrees
  python -m sphinx -T -E -b html -d "$doctrees" -D language=en "$sourcedir" "$outdir"
  #make html
  #python -m sphinx -T -E -b html -d _build/doctrees -D language=en . $READTHEDOCS_OUTPUT/html

  echo "HTML build, to view, run:"
  echo "python3 -m http.server --directory $BUILD_WORKSPACE_DIRECTORY/docs/build/html"
  #python3 -m http.server --directory $BUILD_WORKSPACE_DIRECTORY/docs/build/html
fi
