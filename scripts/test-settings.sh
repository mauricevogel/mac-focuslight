#!/bin/bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_build="$repo_root/build/settings-tests"
mkdir -p "$test_build"

xcrun swiftc -parse-as-library -module-cache-path "$test_build/module-cache" \
    "$repo_root/FocusLight/AppSettings.swift" \
    "$repo_root/FocusLight/SettingsConfiguration.swift" \
    "$repo_root/tests/SettingsTests.swift" \
    -o "$test_build/SettingsTests"

"$test_build/SettingsTests"
