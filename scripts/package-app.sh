#!/bin/bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if ! xcrun --find xcodebuild >/dev/null 2>&1; then
    printf 'Install Xcode and select it as the active developer directory before building.\n' >&2
    exit 1
fi

# Ad hoc signing supports local use without an Apple Developer account.
# Build both Mac architectures so the bundle works on Apple silicon and Intel.
xcodebuild \
    -project "$repo_root/FocusLight.xcodeproj" \
    -scheme FocusLight \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$repo_root/build" \
    "CONFIGURATION_BUILD_DIR=$repo_root/dist" \
    'ARCHS=arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM= \
    build

codesign --verify --strict "$repo_root/dist/FocusLight.app"

printf '\nBuilt: %s/dist/FocusLight.app\n' "$repo_root"
printf 'Quit any running copy, then drag FocusLight.app into Applications and double-click it.\n'
