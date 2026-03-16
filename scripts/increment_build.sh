#!/bin/bash
# scripts/increment_build.sh

if [ -z "$1" ]; then
  echo "Usage: ./scripts/increment_build.sh <platform>"
  echo "Example: ./scripts/increment_build.sh macos"
  exit 1
fi

PLATFORM=$1
VERSION_FILE="scripts/version_${PLATFORM}.txt"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "Error: $VERSION_FILE not found"
  exit 1
fi

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
OLD_BASE_VERSION="${CURRENT_VERSION%+*}"
BUILD_NUM="${CURRENT_VERSION#*+}"

if [[ -f "pubspec.yaml" ]]; then
  BASE_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1 | tr -d '\r')
else
  BASE_VERSION="$OLD_BASE_VERSION"
fi

if [[ "$CURRENT_VERSION" != *"+"* || -z "$BUILD_NUM" ]]; then
  NEW_BUILD_NUM=1
else
  NEW_BUILD_NUM=$((BUILD_NUM + 1))
fi

NEW_VERSION="$BASE_VERSION+$NEW_BUILD_NUM"

echo "$NEW_VERSION" > "$VERSION_FILE"

echo "$NEW_VERSION"
