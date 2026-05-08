#!/bin/bash

# SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
shopt -s nullglob

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -d "$ROOT_DIR/.deps_vendor" ]]; then
  if [[ "${1:-}" == '--force' ]]; then
    printf 'The .deps_vendor directory already exists. Removing it...\n'
    rm -rf "$ROOT_DIR/.deps_vendor"
  else
    printf 'ERROR: The .deps_vendor directory already exists. Exiting...\n'
    exit 1
  fi
fi

if [[ -n "$VCPKG_ROOT" ]]; then
  printf 'ERROR: VCPKG_ROOT is not defined.\n'
fi

printf '#==> Checking if required tools can be called without errors.\n'

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    printf "Found %s.\n" "$1"
  else
    printf "ERROR: %S is not available.\n" "$1"
    exit 1
  fi
}

check_command cmake
cmake --version

check_command git
git --version

check_command ninja
ninja --version

check_command pkg-config
pkg-config --version

check_command xcodebuild
xcodebuild -version

printf '\n#==> Installing dependencies\n'

with_clean_env() {
  envvars=(
    HOME="$HOME"
    PATH="/usr/bin:/bin:/usr/sbin:/sbin"
    VCPKG_BINARY_SOURCES="default;http,https://vcpkg-obs.kaito.tokyo/{name}/{version}/{sha}"
    VCPKG_ROOT="$VCPKG_ROOT"
  )
  env -i "${envvars[@]}" "$@"
}

with_clean_env "${VCPKG_ROOT}/vcpkg" install --triplet=arm64-osx-obs --x-install-root="$ROOT_DIR/.deps_vendor/vcpkg_installed_arm64"
with_clean_env "${VCPKG_ROOT}/vcpkg" install --triplet=x64-osx-obs --x-install-root="$ROOT_DIR/.deps_vendor/vcpkg_installed_x64"

./scripts/lipo_vcpkg_macos.sh \
  .deps_vendor/vcpkg_installed_universal/universal-osx-obs \
  .deps_vendor/vcpkg_installed_arm64/arm64-osx-obs \
  .deps_vendor/vcpkg_installed_x64/x64-osx-obs

cmake -P scripts/download_deps.cmake

./scripts/build_libobs_macos.sh
