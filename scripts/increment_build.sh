#!/bin/bash
# scripts/increment_build.sh

PUBSPEC="pubspec.yaml"
if [[ ! -f "$PUBSPEC" ]]; then
  echo "Error: pubspec.yaml not found"
  exit 1
fi

CURRENT_VERSION=$(grep -m 1 '^version: ' "$PUBSPEC" | awk '{print $2}')
BASE_VERSION="${CURRENT_VERSION%+*}"
BUILD_NUM="${CURRENT_VERSION#*+}"

if [[ "$CURRENT_VERSION" != *"+"* ]]; then
  NEW_BUILD_NUM=1
else
  NEW_BUILD_NUM=$((BUILD_NUM + 1))
fi

NEW_VERSION="$BASE_VERSION+$NEW_BUILD_NUM"

awk -v new_ver="$NEW_VERSION" '{
  if ($1 == "version:") {
    print "version: " new_ver
  } else {
    print $0
  }
}' "$PUBSPEC" > "$PUBSPEC.tmp"

mv "$PUBSPEC.tmp" "$PUBSPEC"

echo "$NEW_VERSION"
