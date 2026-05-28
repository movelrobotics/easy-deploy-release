#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
WORK_DIR="${WORK_DIR:-${DIST_DIR}/.work}"
RELEASE_AUTHOR="${RELEASE_AUTHOR:-Movel AI}"
BUILD_DATE=""

ROS1_CONFIG_DIR="${ROS1_CONFIG_DIR:-${ROOT_DIR}/rns-config-release-2.73.0}"
ROS2_CONFIG_DIR="${ROS2_CONFIG_DIR:-${ROOT_DIR}/rns-config2-release-5.3.0}"

usage() {
    cat <<'EOF'
Usage:
  scripts/build_easy_deploy_release.sh [options]

Options:
  --ros1-version VERSION       Override ROS1/RNS version. Default: read from ROS1 config.
  --ros2-version VERSION       Override ROS2/RNS version. Default: read from ROS2 config.
  --dist-dir DIR               Output directory. Default: ./dist
  --ros1-config-dir DIR        ROS1 config directory. Default: ./rns-config-release-2.73.0
  --ros2-config-dir DIR        ROS2 config directory. Default: ./rns-config2-release-5.3.0
  --author NAME                Release author. Default: RELEASE_AUTHOR or "Movel AI".
  --help                       Show this help.

Environment overrides:
  ROS1_X86_TEMPLATE            Path to ROS1 x86 easy-deploy template.
  ROS1_ARM64_TEMPLATE          Path to ROS1 arm64 easy-deploy template.
  ROS2_X86_TEMPLATE            Path to ROS2 x86 easy-deploy template.
  ROS2_ARM64_TEMPLATE          Path to ROS2 arm64 easy-deploy template.

Output assets:
  easy-deploy-ros1-<version>-x86.zip
  easy-deploy-ros1-<version>-arm64.zip
  easy-deploy-ros2-<version>-x86.zip
  easy-deploy-ros2-<version>-arm64.zip

Version is read from seirios_config_release.yml by default and may be a
Docker-tag-compatible value such as 5.3.9 or rns-ros2-adhoc-qt.
EOF
}

log() {
    printf '[build_easy_deploy_release] %s\n' "$*"
}

die() {
    printf '[build_easy_deploy_release] ERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

relative_path() {
    local path=$1
    case "${path}" in
        "${ROOT_DIR}"/*)
            printf './%s' "${path#"${ROOT_DIR}/"}"
            ;;
        *)
            printf '%s' "${path}"
            ;;
    esac
}

read_config_version() {
    local config_dir=$1
    local release_file="${config_dir}/seirios_config_release.yml"

    [[ -f "${release_file}" ]] || die "Missing ${release_file}"
    sed -nE 's/^Version:[[:space:]]*//p' "${release_file}" \
        | head -n 1 \
        | sed -E 's/[[:space:]]+#.*$//; s/^["'"'"']?//; s/["'"'"']?[[:space:]]*$//'
}

validate_version() {
    local label=$1
    local version=$2

    if [[ ! "${version}" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
        die "${label} version '${version}' is not valid for Docker tags/file names. Use letters, numbers, underscore, dot, or dash."
    fi
}

select_latest_path() {
    local label=$1
    shift
    local matches=()
    local candidate

    for candidate in "$@"; do
        [[ -d "${candidate}" ]] && matches+=("${candidate}")
    done

    [[ ${#matches[@]} -gt 0 ]] || die "No template found for ${label}"
    printf '%s\n' "${matches[@]}" | sort -V | tail -n 1
}

discover_templates() {
    shopt -s nullglob globstar

    ROS1_X86_TEMPLATE="${ROS1_X86_TEMPLATE:-$(select_latest_path "ROS1 x86" "${ROOT_DIR}"/movel-ai-easy-deploy-x86_64-*/**/easy-deploy)}"
    ROS1_ARM64_TEMPLATE="${ROS1_ARM64_TEMPLATE:-$(select_latest_path "ROS1 arm64" "${ROOT_DIR}"/movel-ai-easy-deploy-arm64-*/**/easy-deploy)}"
    ROS2_X86_TEMPLATE="${ROS2_X86_TEMPLATE:-$(select_latest_path "ROS2 x86" "${ROOT_DIR}"/easy-deploy-ros2:*-x86)}"
    ROS2_ARM64_TEMPLATE="${ROS2_ARM64_TEMPLATE:-$(select_latest_path "ROS2 arm64" "${ROOT_DIR}"/easy-deploy-ros2:*-arm64)}"

    shopt -u nullglob globstar
}

update_yaml_version() {
    local file=$1
    local image_name=$2
    local version=$3

    [[ -f "${file}" ]] || return 0
    sed -i -E "s#(tag:[[:space:]]*)${image_name}:[^[:space:]]+#\1${image_name}:${version}#" "${file}"
}

update_compose_image() {
    local file=$1
    local image_name=$2
    local version=$3

    [[ -f "${file}" ]] || die "Missing docker compose file: ${file}"
    sed -i -E "s#(image:[[:space:]]*)${image_name}:[^[:space:]]+#\1${image_name}:${version}#" "${file}"
}

update_release_version_file() {
    local file=$1
    local version=$2

    [[ -f "${file}" ]] || return 0
    sed -i -E "1s#^Version:.*#Version: ${version}#" "${file}"
}

write_release_info() {
    local package_dir=$1
    local package_name=$2
    local ros_line=$3
    local arch=$4
    local version=$5
    local image_name=$6
    local template_dir=$7
    local config_dir=$8
    local info_file="${package_dir}/release_info.json"

    cat > "${info_file}" <<EOF
{
  "package_name": "$(json_escape "${package_name}")",
  "file_name": "$(json_escape "${package_name}.zip")",
  "author": "$(json_escape "${RELEASE_AUTHOR}")",
  "build_date": "$(json_escape "${BUILD_DATE}")",
  "ros": "$(json_escape "${ros_line}")",
  "version": "$(json_escape "${version}")",
  "arch": "$(json_escape "${arch}")",
  "docker_compose": "files/catkin_ws/movel_ai/docker-compose.yaml",
  "docker_image": "$(json_escape "${image_name}:${version}")",
  "config_path": "files/catkin_ws/movel_ai/config",
  "config_source": "$(json_escape "$(relative_path "${config_dir}")")",
  "template_source": "$(json_escape "$(relative_path "${template_dir}")")"
}
EOF
}

enable_config_overwrite() {
    local install_file=$1

    [[ -f "${install_file}" ]] || die "Missing install script: ${install_file}"

    if ! grep -q 'f_copy_folder_overwrite' "${install_file}"; then
        sed -i '/^function f_copy_file_if_not_exists/ i\
function f_copy_folder_overwrite {\
    SRC_DIR=$1\
    SUB_DIR=$2\
    if [ -z "${SUB_DIR}" ] || [ "${SUB_DIR}" = "/" ]; then\
        f_echo_red "[${SCRIPT_NAME}] Refusing to overwrite unsafe directory: ${SUB_DIR}"\
        exit 1\
    fi\
    if [ -d "${SUB_DIR}" ]; then\
        f_echo_magenta "[${SCRIPT_NAME}] Overwriting folder ${SUB_DIR} from source ${SRC_DIR}"\
        rm -rf "${SUB_DIR}"\
    else\
        f_echo_magenta "[${SCRIPT_NAME}] Creating folder ${SUB_DIR} from source ${SRC_DIR}"\
    fi\
    cp -r "${SRC_DIR}" "${SUB_DIR}"\
}\
' "${install_file}"
    fi

    sed -i '0,/f_copy_folder_if_not_exists $SRC_DIR $SUB_DIR/s//f_copy_folder_overwrite $SRC_DIR $SUB_DIR/' "${install_file}"
}

build_package() {
    local ros_line=$1
    local arch=$2
    local version=$3
    local template_dir=$4
    local config_dir=$5

    local service_name image_name package_name package_dir config_target compose_file
    package_name="easy-deploy-${ros_line}-${version}-${arch}"
    package_dir="${WORK_DIR}/${package_name}"

    if [[ "${ros_line}" == "ros1" ]]; then
        service_name="seirios-ros"
        image_name="movelrobots/rns-ros"
    else
        service_name="seirios-ros2"
        image_name="movelrobots/rns-ros2"
    fi

    [[ -d "${template_dir}" ]] || die "Template does not exist: ${template_dir}"
    [[ -d "${config_dir}" ]] || die "Config directory does not exist: ${config_dir}"

    log "Building ${package_name}"
    rm -rf "${package_dir}"
    mkdir -p "${package_dir}"
    cp -a "${template_dir}/." "${package_dir}/"

    config_target="${package_dir}/files/catkin_ws/movel_ai/config"
    rm -rf "${config_target}"
    mkdir -p "$(dirname "${config_target}")"
    cp -a "${config_dir}" "${config_target}"
    update_release_version_file "${config_target}/seirios_config_release.yml" "${version}"

    printf '%s\n' "${arch}" > "${package_dir}/ARCH.txt"
    printf '%s\n' "${BUILD_DATE}" > "${package_dir}/PACKAGE_DATE.txt"

    compose_file="${package_dir}/files/catkin_ws/movel_ai/docker-compose.yaml"
    update_compose_image "${compose_file}" "${image_name}" "${version}"

    local version_file
    for version_file in "${package_dir}"/version_config*.yaml; do
        update_yaml_version "${version_file}" "${image_name}" "${version}"
    done

    if ! grep -q "${service_name}:" "${compose_file}"; then
        die "${package_name}: expected service ${service_name} in ${compose_file}"
    fi

    enable_config_overwrite "${package_dir}/install/install_catkin_ws.sh"
    write_release_info "${package_dir}" "${package_name}" "${ros_line}" "${arch}" "${version}" "${image_name}" "${template_dir}" "${config_dir}"

    local output_zip="${DIST_DIR}/${package_name}.zip"
    rm -f "${output_zip}"
    (cd "${WORK_DIR}" && zip -qr "${output_zip}" "${package_name}")
    log "Created ${output_zip}"
}

write_manifest() {
    local manifest_file="${DIST_DIR}/manifest.json"
    cat > "${manifest_file}" <<EOF
{
  "generated_at": "$(date -Iseconds)",
  "author": "$(json_escape "${RELEASE_AUTHOR}")",
  "assets": [
    {
      "ros": "ros1",
      "version": "${ROS1_VERSION}",
      "arch": "x86",
      "file": "easy-deploy-ros1-${ROS1_VERSION}-x86.zip",
      "github_release_tag": "ros1-${ROS1_VERSION}"
    },
    {
      "ros": "ros1",
      "version": "${ROS1_VERSION}",
      "arch": "arm64",
      "file": "easy-deploy-ros1-${ROS1_VERSION}-arm64.zip",
      "github_release_tag": "ros1-${ROS1_VERSION}"
    },
    {
      "ros": "ros2",
      "version": "${ROS2_VERSION}",
      "arch": "x86",
      "file": "easy-deploy-ros2-${ROS2_VERSION}-x86.zip",
      "github_release_tag": "ros2-${ROS2_VERSION}"
    },
    {
      "ros": "ros2",
      "version": "${ROS2_VERSION}",
      "arch": "arm64",
      "file": "easy-deploy-ros2-${ROS2_VERSION}-arm64.zip",
      "github_release_tag": "ros2-${ROS2_VERSION}"
    }
  ]
}
EOF
    log "Created ${manifest_file}"
}

ROS1_VERSION=""
ROS2_VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ros1-version)
            ROS1_VERSION=$2
            shift 2
            ;;
        --ros2-version)
            ROS2_VERSION=$2
            shift 2
            ;;
        --dist-dir)
            DIST_DIR=$2
            WORK_DIR="${DIST_DIR}/.work"
            shift 2
            ;;
        --ros1-config-dir)
            ROS1_CONFIG_DIR=$2
            shift 2
            ;;
        --ros2-config-dir)
            ROS2_CONFIG_DIR=$2
            shift 2
            ;;
        --author)
            RELEASE_AUTHOR=$2
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

require_command zip
require_command sed
require_command sort

ROS1_VERSION="${ROS1_VERSION:-$(read_config_version "${ROS1_CONFIG_DIR}")}"
ROS2_VERSION="${ROS2_VERSION:-$(read_config_version "${ROS2_CONFIG_DIR}")}"
BUILD_DATE="$(date -Iseconds)"

[[ -n "${ROS1_VERSION}" ]] || die "Could not read ROS1 version"
[[ -n "${ROS2_VERSION}" ]] || die "Could not read ROS2 version"
validate_version "ROS1" "${ROS1_VERSION}"
validate_version "ROS2" "${ROS2_VERSION}"

discover_templates

log "ROS1 version: ${ROS1_VERSION}"
log "ROS2 version: ${ROS2_VERSION}"
log "Release author: ${RELEASE_AUTHOR}"
log "Build date: ${BUILD_DATE}"
log "ROS1 x86 template: ${ROS1_X86_TEMPLATE}"
log "ROS1 arm64 template: ${ROS1_ARM64_TEMPLATE}"
log "ROS2 x86 template: ${ROS2_X86_TEMPLATE}"
log "ROS2 arm64 template: ${ROS2_ARM64_TEMPLATE}"

mkdir -p "${DIST_DIR}" "${WORK_DIR}"

build_package "ros1" "x86" "${ROS1_VERSION}" "${ROS1_X86_TEMPLATE}" "${ROS1_CONFIG_DIR}"
build_package "ros1" "arm64" "${ROS1_VERSION}" "${ROS1_ARM64_TEMPLATE}" "${ROS1_CONFIG_DIR}"
build_package "ros2" "x86" "${ROS2_VERSION}" "${ROS2_X86_TEMPLATE}" "${ROS2_CONFIG_DIR}"
build_package "ros2" "arm64" "${ROS2_VERSION}" "${ROS2_ARM64_TEMPLATE}" "${ROS2_CONFIG_DIR}"

write_manifest

log "Done. Upload the zip files in ${DIST_DIR} to GitHub Releases."
