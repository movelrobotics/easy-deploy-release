#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${EASY_DEPLOY_GITHUB_REPO:-}"
VERSION=""
ROS_LINE=""
ARCH_OVERRIDE=""
DOWNLOAD_DIR="${EASY_DEPLOY_DOWNLOAD_DIR:-${HOME}/Downloads/easy-deploy}"
INSTALL_AFTER_DOWNLOAD=1
ASSUME_YES=0

usage() {
    cat <<'EOF'
Usage:
  install_easy_deploy.sh --repo OWNER/REPO --version VERSION [options]
  install_easy_deploy.sh --repo OWNER/REPO --ros ros1 --version latest [options]

Examples:
  EASY_DEPLOY_GITHUB_REPO=company/easy-deploy ./install_easy_deploy.sh --ros ros1 --version latest
  EASY_DEPLOY_GITHUB_REPO=company/easy-deploy ./install_easy_deploy.sh --ros ros2 --version latest
  EASY_DEPLOY_GITHUB_REPO=company/easy-deploy ./install_easy_deploy.sh --ros ros2 --version bundle-1.0.0

Options:
  --repo OWNER/REPO        GitHub repository that stores release assets.
                           Can also use EASY_DEPLOY_GITHUB_REPO.
  --version VERSION        RNS version, or latest.
  --ros ros1|ros2          Required only when --version latest is used.
                           Also required for non-numeric versions.
  --arch x86|arm64         Override detected architecture. Use with --no-install
                           when downloading for another machine.
  --download-dir DIR       Download/extract directory. Default: ~/Downloads/easy-deploy
  --no-install             Download and extract only.
  -y, --yes                Do not ask confirmation before running installer.
  --help                   Show this help.

Release convention expected by this script:
  Tag:   ros1-bundle-1.0.0
  Asset: easy-deploy-ros1-bundle-1.0.0-x86.zip

  Tag:   ros2-bundle-1.0.0
  Asset: easy-deploy-ros2-bundle-1.0.0-arm64.zip

  Tag:   ros2-rns-ros2-adhoc-qt
  Asset: easy-deploy-ros2-rns-ros2-adhoc-qt-x86.zip
EOF
}

log() {
    printf '[install_easy_deploy] %s\n' "$*"
}

die() {
    printf '[install_easy_deploy] ERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

normalize_ros_line() {
    case "$1" in
        ros1|ROS1|1|rns-ros)
            printf 'ros1'
            ;;
        ros2|ROS2|2|rns-ros2)
            printf 'ros2'
            ;;
        *)
            die "Unsupported ROS value: $1"
            ;;
    esac
}

infer_ros_line_from_version() {
    local version=$1
    case "${version%%.*}" in
        2)
            printf 'ros1'
            ;;
        5)
            printf 'ros2'
            ;;
        *)
            die "Cannot infer ROS line from version ${version}. Use --ros ros1 or --ros ros2."
            ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)
            printf 'x86'
            ;;
        aarch64|arm64)
            printf 'arm64'
            ;;
        *)
            die "Unsupported machine architecture: $(uname -m)"
            ;;
    esac
}

normalize_arch() {
    case "$1" in
        x86|x86_64|amd64)
            printf 'x86'
            ;;
        arm64|aarch64)
            printf 'arm64'
            ;;
        *)
            die "Unsupported architecture override: $1. Use x86 or arm64."
            ;;
    esac
}

github_api_get() {
    local url=$1
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        curl -fsSL \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H 'Accept: application/vnd.github+json' \
            "${url}"
    else
        curl -fsSL \
            -H 'Accept: application/vnd.github+json' \
            "${url}"
    fi
}

resolve_latest_version() {
    local repo=$1
    local ros_line=$2
    local releases_api="https://api.github.com/repos/${repo}/releases?per_page=100"
    local version

    version=$(github_api_get "${releases_api}" \
        | sed -nE 's/.*"tag_name":[[:space:]]*"([^"[:space:]]+)".*/\1/p' \
        | sed -nE "s/^${ros_line}-(.+)$/\1/p" \
        | head -n 1)

    [[ -n "${version}" ]] || die "No GitHub Release found for ${ros_line} in ${repo}"
    printf '%s' "${version}"
}

download_asset() {
    local repo=$1
    local tag=$2
    local asset=$3
    local output_file=$4

    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        local release_api="https://api.github.com/repos/${repo}/releases/tags/${tag}"
        local asset_api_url

        asset_api_url=$(github_api_get "${release_api}" \
            | tr '\n' ' ' \
            | sed 's/},[[:space:]]*{/}\n{/g' \
            | grep -F "\"name\": \"${asset}\"" \
            | sed -nE 's/.*"url":[[:space:]]*"([^"]+)".*/\1/p' \
            | head -n 1)

        [[ -n "${asset_api_url}" ]] || die "Asset ${asset} not found in release ${tag}"

        curl -fL \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H 'Accept: application/octet-stream' \
            -o "${output_file}" \
            "${asset_api_url}"
    else
        local url="https://github.com/${repo}/releases/download/${tag}/${asset}"
        curl -fL \
            -o "${output_file}" \
            "${url}"
    fi
}

overwrite_existing_config() {
    local package_dir=$1
    local source_config="${package_dir}/files/catkin_ws/movel_ai/config"
    local target_config="${HOME}/catkin_ws/movel_ai/config"

    [[ -d "${source_config}" ]] || die "Package config not found: ${source_config}"

    if [[ -d "${target_config}" ]]; then
        log "Overwriting existing config: ${target_config}"
        rm -rf "${target_config}"
        cp -a "${source_config}" "${target_config}"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            REPO=$2
            shift 2
            ;;
        --version)
            VERSION=$2
            shift 2
            ;;
        --ros)
            ROS_LINE=$(normalize_ros_line "$2")
            shift 2
            ;;
        --arch)
            ARCH_OVERRIDE=$(normalize_arch "$2")
            shift 2
            ;;
        --download-dir)
            DOWNLOAD_DIR=$2
            shift 2
            ;;
        --no-install)
            INSTALL_AFTER_DOWNLOAD=0
            shift
            ;;
        -y|--yes)
            ASSUME_YES=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            if [[ -z "${VERSION}" ]]; then
                VERSION=$1
                shift
            else
                die "Unknown option: $1"
            fi
            ;;
    esac
done

[[ -n "${REPO}" ]] || die "GitHub repo is required. Use --repo OWNER/REPO or EASY_DEPLOY_GITHUB_REPO."
[[ -n "${VERSION}" ]] || die "Version is required. Use --version VERSION or --version latest."

require_command curl
require_command grep
require_command sed
require_command unzip

if [[ "${VERSION}" == "latest" ]]; then
    [[ -n "${ROS_LINE}" ]] || die "--ros ros1|ros2 is required when --version latest is used."
    VERSION=$(resolve_latest_version "${REPO}" "${ROS_LINE}")
else
    ROS_LINE="${ROS_LINE:-$(infer_ros_line_from_version "${VERSION}")}"
fi

DETECTED_ARCH=$(detect_arch)
ARCH="${ARCH_OVERRIDE:-${DETECTED_ARCH}}"

if [[ -n "${ARCH_OVERRIDE}" && "${ARCH_OVERRIDE}" != "${DETECTED_ARCH}" && "${INSTALL_AFTER_DOWNLOAD}" -eq 1 ]]; then
    die "Requested --arch ${ARCH_OVERRIDE}, but this machine is ${DETECTED_ARCH}. Use --no-install to download for another machine."
fi

TAG="${ROS_LINE}-${VERSION}"
ASSET="easy-deploy-${ROS_LINE}-${VERSION}-${ARCH}.zip"
ZIP_FILE="${DOWNLOAD_DIR}/${ASSET}"
PACKAGE_DIR="${DOWNLOAD_DIR}/${ASSET%.zip}"

log "ROS line: ${ROS_LINE}"
log "Version: ${VERSION}"
log "Detected architecture: ${DETECTED_ARCH}"
log "Package architecture: ${ARCH}"
log "Release tag: ${TAG}"
log "Asset: ${ASSET}"

mkdir -p "${DOWNLOAD_DIR}"
download_asset "${REPO}" "${TAG}" "${ASSET}" "${ZIP_FILE}"
log "Downloaded ${ZIP_FILE}"

rm -rf "${PACKAGE_DIR}"
unzip -q "${ZIP_FILE}" -d "${DOWNLOAD_DIR}"
[[ -d "${PACKAGE_DIR}" ]] || die "Extracted package directory not found: ${PACKAGE_DIR}"
log "Extracted ${PACKAGE_DIR}"

if [[ "${INSTALL_AFTER_DOWNLOAD}" -eq 0 ]]; then
    log "Download/extract only requested. Installer not executed."
    exit 0
fi

if [[ "${ASSUME_YES}" -eq 0 ]]; then
    printf 'Run Easy Deploy installer now? [y/N] '
    read -r answer
    case "${answer}" in
        y|Y|yes|YES)
            ;;
        *)
            log "Installer skipped. Run manually: cd '${PACKAGE_DIR}' && bash install-2-seirios.sh"
            exit 0
            ;;
    esac
fi

overwrite_existing_config "${PACKAGE_DIR}"
cd "${PACKAGE_DIR}"
bash install-2-seirios.sh
