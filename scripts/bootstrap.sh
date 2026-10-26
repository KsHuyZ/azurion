#!/usr/bin/env bash
# One-time setup: fetch Azahar and its dependencies, apply Azurion's core patches and generate
# the Xcode project. Safe to run again.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AZAHAR="$ROOT/external/azahar"

for tool in cmake ninja xcodegen xcodebuild; do
    if ! command -v "$tool" >/dev/null; then
        echo "error: '$tool' not found. Install Xcode, then: brew install cmake ninja xcodegen" >&2
        exit 1
    fi
done

echo "==> Fetching Azahar and its dependencies"
git -C "$ROOT" submodule update --init external/azahar
git -C "$AZAHAR" submodule update --init --recursive --depth 1 --jobs 8

echo "==> Applying patches/azahar"
for patch in "$ROOT"/patches/azahar/*.patch; do
    name="$(basename "$patch")"
    if git -C "$AZAHAR" apply --reverse --check "$patch" 2>/dev/null; then
        echo "    already applied: $name"
    else
        git -C "$AZAHAR" apply "$patch"
        echo "    applied: $name"
    fi
done

echo "==> Generating Azurion.xcodeproj"
(cd "$ROOT" && xcodegen generate)

echo
echo "Next: scripts/build-core.sh, then open Azurion.xcodeproj"
