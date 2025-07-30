#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "Tauri CLI is installed" cargo-tauri --version

tauri_info=$(cargo tauri info)
check "Tauri requirements met" sh -c "echo \"$tauri_info\" | grep ✔"
check "No error in tauri info" sh -c "echo \"$tauri_info\" | grep -vz ✘ >/dev/null"
check "No warning in tauri info" sh -c "echo \"$tauri_info\" | grep -vz ⚠ >/dev/null"

reportResults
