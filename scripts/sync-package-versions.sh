#!/bin/sh
# shellcheck shell=dash

#
# Synchronises package version with the version in the project root.
# Also synchronizes package dependencies
#
# Note: probably would be better to use something like Lerna here.........
#
# Requires jq.
#
# Usage: ./sync-package-versions.sh [version]
#

set -e

cd "$(dirname "$0")/../"

PROJECT_VERSION=$(jq -r ".version" package.json)
VERSION=${1:-"$PROJECT_VERSION"}

cd packages/

for PACKAGE in */package.json; do
  PACKAGE_NAME="${PACKAGE%%/*}"
  cd "$PACKAGE_NAME" || exit 1

  PACKAGE_VERSION=$(jq -r ".version" package.json)

  if [ "$PACKAGE_VERSION" != "$VERSION" ]; then
    echo "Updating $PACKAGE_NAME version ..."
    
    JSON=$(jq -r \
      ".version |= \"$VERSION\"" \
      package.json
    )

    HAS_LAMBDA_DEPENDENCY=$(echo "$JSON" | \
      jq -r \
      ".dependencies | has(\"@serverless-chrome/lambda\")"
    )

    if [ "$HAS_LAMBDA_DEPENDENCY" = "true" ]; then
      JSON=$(echo "$JSON" | \
        jq -r \
        ".dependencies.\"@serverless-chrome/lambda\" |= \"$VERSION\""
      )
    fi

    echo "$JSON" > package.json

    # @TODO: run yarn to update lockfile
    # chicken-before-the-egg problem. The following won't work because yarn
    # will try to look for the new package version on the npm registry, but
    # of course it won't find it because it's not been published yet..
    #yarn --ignore-scripts --non-interactive
  else
    echo "$PACKAGE_NAME version $VERSION is already latest. Skipping.."
  fi

  cd ../
done

# @TODO: update integration-test and example dependencies, too
