#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "tauri CLI version is equal to 2.7.0" sh -c "cargo-tauri --version | grep '2.7.0'"

tauri_info=$(cargo tauri info)
check "Tauri requirements met" sh -c "echo \"$tauri_info\" | grep ✔"
check "No error in tauri info" sh -c "echo \"$tauri_info\" | grep -vz ✘ >/dev/null"
check "No warning in tauri info" sh -c "echo \"$tauri_info\" | grep -vz ⚠ >/dev/null"

reportResults
