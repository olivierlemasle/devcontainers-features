#!/usr/bin/env bash

set -e

TAURI_VERSION="${VERSION:-"latest"}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Ensure that login shells get the correct path if the user updated the PATH using ENV.
rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" >/etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh

if ! type rustc >/dev/null 2>&1 || ! type cargo >/dev/null 2>&1; then
    echo "Rust not installed. This feature requires Rust."
    exit 1
fi

# Bring in ID, ID_LIKE, VERSION_ID, VERSION_CODENAME
. /etc/os-release
# Get an adjusted ID independent of distro variants
if [ "${ID}" = "debian" ] || [ "${ID_LIKE}" = "debian" ]; then
    ADJUSTED_ID="debian"
elif [[ "${ID}" = "rhel" || "${ID}" = "fedora" || "${ID_LIKE}" = *"rhel"* || "${ID_LIKE}" = *"fedora"* ]]; then
    ADJUSTED_ID="rhel"
else
    echo "Linux distro ${ID} not supported."
    exit 1
fi

# Detect package manager
if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
elif command -v microdnf >/dev/null 2>&1; then
    PKG_MANAGER="microdnf"
elif command -v tdnf >/dev/null 2>&1; then
    PKG_MANAGER="tdnf"
else
    echo "No supported package manager found. Supported: apt, dnf, yum, microdnf, tdnf"
    exit 1
fi

echo "Detected package manager: $PKG_MANAGER"

# Clean up based on package manager
clean_package_cache() {
    case "$PKG_MANAGER" in
    apt)
        if [ "$(ls -1 /var/lib/apt/lists/ 2>/dev/null | wc -l)" -gt 0 ]; then
            rm -rf /var/lib/apt/lists/*
        fi
        ;;
    dnf | yum | microdnf)
        if command -v dnf >/dev/null 2>&1; then
            dnf clean all
        elif command -v yum >/dev/null 2>&1; then
            yum clean all
        elif command -v microdnf >/dev/null 2>&1; then
            microdnf clean all
        fi
        ;;
    tdnf)
        tdnf clean all
        ;;
    esac
}

# Initial cleanup
clean_package_cache

# Package update functions
pkg_mgr_update() {
    case "$PKG_MANAGER" in
    apt)
        if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then
            echo "Running apt-get update..."
            apt-get update -y
        fi
        ;;
    dnf)
        dnf check-update || true
        ;;
    yum)
        yum check-update || true
        ;;
    microdnf)
        # microdnf doesn't have check-update
        true
        ;;
    tdnf)
        tdnf makecache || true
        ;;
    esac
}

# Check if package is installed
is_package_installed() {
    local package=$1
    case "$PKG_MANAGER" in
    apt)
        dpkg -s "$package" >/dev/null 2>&1
        ;;
    dnf | yum | microdnf | tdnf)
        rpm -q "$package" >/dev/null 2>&1
        ;;
    esac
}

# Unified package checking and installation function
check_packages() {
    local packages=("$@")
    local missing_packages=()

    # Check if curl-minimal is installed and swap it with curl
    if is_package_installed "curl-minimal"; then
        echo "curl-minimal is installed. Swapping it with curl..."
        case "$PKG_MANAGER" in
        dnf | yum | microdnf)
            ${PKG_MANAGER} swap curl-minimal curl -y
            ;;
        tdnf)
            tdnf remove -y curl-minimal
            tdnf install -y curl
            ;;
        *)
            echo "Package manager does not support swapping curl-minimal with curl. Please handle this manually."
            ;;
        esac
    fi

    # Check which packages are missing
    for package in "${packages[@]}"; do
        if [ -n "$package" ] && ! is_package_installed "$package"; then
            missing_packages+=("$package")
        fi
    done

    # Install missing packages
    if [ ${#missing_packages[@]} -gt 0 ]; then
        pkg_mgr_update
        case "$PKG_MANAGER" in
        apt)
            apt-get -y install --no-install-recommends "${missing_packages[@]}"
            ;;
        dnf)
            dnf install -y "${missing_packages[@]}"
            ;;
        yum)
            yum install -y "${missing_packages[@]}"
            ;;
        microdnf)
            microdnf install -y "${missing_packages[@]}"
            ;;
        tdnf)
            tdnf install -y "${missing_packages[@]}"
            ;;
        esac
    fi
}

export DEBIAN_FRONTEND=noninteractive

echo "Installing required dependencies..."
case ${ADJUSTED_ID} in
debian)
    check_packages \
        git \
        libwebkit2gtk-4.1-dev \
        curl \
        wget \
        file \
        libxdo-dev \
        libssl-dev \
        libayatana-appindicator3-dev \
        librsvg2-dev \
        build-essential \
        patchelf
    ;;
rhel)
    check_packages \
        git \
        webkit2gtk4.1-devel \
        curl \
        wget \
        file \
        libxdo-devel \
        openssl-devel \
        libappindicator-gtk3-devel \
        librsvg2-devel \
        gcc gcc-c++ pkgconf make glibc-devel \
        patchelf
    ;;
esac

# Figure out correct version of a three part version number is not passed
find_version_from_git_tags() {
    local variable_name=$1
    local requested_version=${!variable_name}
    if [ "${requested_version}" = "none" ]; then return; fi
    local repository=$2
    local prefix=${3:-"tags/v"}
    local separator=${4:-"."}
    local last_part_optional=${5:-"false"}
    if [ "$(echo "${requested_version}" | grep -o "." | wc -l)" != "2" ]; then
        local escaped_separator=${separator//./\\.}
        local last_part
        if [ "${last_part_optional}" = "true" ]; then
            last_part="(${escaped_separator}[0-9]+)?"
        else
            last_part="${escaped_separator}[0-9]+"
        fi
        local regex="${prefix}\\K[0-9]+${escaped_separator}[0-9]+${last_part}$"
        local version_list="$(git ls-remote --tags ${repository} | grep -oP "${regex}" | tr -d ' ' | tr "${separator}" "." | sort -rV)"
        if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "current" ] || [ "${requested_version}" = "lts" ]; then
            declare -g ${variable_name}="$(echo "${version_list}" | head -n 1)"
        else
            set +e
            declare -g ${variable_name}="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
            set -e
        fi
    fi
    if [ -z "${!variable_name}" ] || ! echo "${version_list}" | grep "^${!variable_name//./\\.}$" >/dev/null 2>&1; then
        echo -e "Invalid ${variable_name} value: ${requested_version}\nValid values:\n${version_list}" >&2
        exit 1
    fi
    echo "${variable_name}=${!variable_name}"
}
find_version_from_git_tags TAURI_VERSION "https://github.com/tauri-apps/tauri.git" "tags/tauri-cli-v"

target_triple="x86_64-unknown-linux-gnu"

echo "Installing Tauri CLI version ${TAURI_VERSION}..."
tmp_path=/tmp/tauri
mkdir -p "${tmp_path}"
tauri_cli_filename="cargo-tauri-${target_triple}.tgz"
tmp_tauri_cli_archive="${tmp_path}/${tauri_cli_filename}"
curl -sSL "https://github.com/tauri-apps/tauri/releases/download/tauri-cli-v${TAURI_VERSION}/${tauri_cli_filename}" -o "${tmp_tauri_cli_archive}"
tar xf "${tmp_tauri_cli_archive}" -C "${tmp_path}"
mv -f "${tmp_path}/cargo-tauri" /usr/local/bin/
chmod 0755 /usr/local/bin/cargo-tauri
rm -rf "${tmp_path}"
if ! type cargo-tauri >/dev/null 2>&1; then
    echo 'cargo-tauri installation failed!'
    exit 1
fi

echo 'Done!'
