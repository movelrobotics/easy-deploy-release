#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
WORK_DIR="${WORK_DIR:-${DIST_DIR}/.work}"
RELEASE_AUTHOR="${RELEASE_AUTHOR:-Movel AI}"
AUTHOR_SET=0
BUILD_DATE=""
DEPLOY_FOR="${DEPLOY_FOR:-both}"

ROS1_CONFIG_DIR="${ROS1_CONFIG_DIR:-${ROOT_DIR}/rns-config-release-2.73.0}"
ROS2_CONFIG_DIR="${ROS2_CONFIG_DIR:-${ROOT_DIR}/rns-config2-release-5.3.0}"
ROS1_MANIFEST="${ROS1_MANIFEST:-${ROOT_DIR}/manifests/ros1-release.yaml}"
ROS2_MANIFEST="${ROS2_MANIFEST:-${ROOT_DIR}/manifests/ros2-release.yaml}"

usage() {
    cat <<'EOF'
Usage:
  scripts/build_easy_deploy_release.sh [options]

Options:
  --ros1-manifest FILE         ROS1 release bundle manifest.
                               Default: ./manifests/ros1-release.yaml
  --ros2-manifest FILE         ROS2 release bundle manifest.
                               Default: ./manifests/ros2-release.yaml
  --ros1-version VERSION       Override ROS1 bundle id/package version.
  --ros2-version VERSION       Override ROS2 bundle id/package version.
  --dist-dir DIR               Output directory. Default: ./dist
  --ros1-config-dir DIR        Fallback ROS1 config directory.
  --ros2-config-dir DIR        Fallback ROS2 config directory.
  --author NAME                Release author. Default: manifest author,
                               RELEASE_AUTHOR, or "Movel AI".
  --deploy-for TARGET          Which ros line(s) to build: ros1, ros2, or both.
                               Default: both. When set to a single ros line,
                               the other line's config/manifest are not read
                               and its packages are not built.
  --help                       Show this help.

Environment overrides:
  ROS1_X86_TEMPLATE            Path to ROS1 x86 easy-deploy template.
  ROS1_ARM64_TEMPLATE          Path to ROS1 arm64 easy-deploy template.
  ROS2_X86_TEMPLATE            Path to ROS2 x86 easy-deploy template.
  ROS2_ARM64_TEMPLATE          Path to ROS2 arm64 easy-deploy template.

Output assets:
  easy-deploy-ros1-<bundle-id>-x86.zip
  easy-deploy-ros1-<bundle-id>-arm64.zip
  easy-deploy-ros2-<bundle-id>-x86.zip
  easy-deploy-ros2-<bundle-id>-arm64.zip

The bundle id comes from bundle.id in the release manifest. The config version
still comes from seirios_config_release.yml inside the selected config folder.
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

strip_yaml_value() {
    local value=$1
    value="${value%%#*}"
    printf '%s' "${value}" | sed -E "s/^[[:space:]]+//; s/[[:space:]]+$//; s/^\"//; s/\"$//; s/^'//; s/'$//"
}

relative_path() {
    local path=$1
    case "${path}" in
        "${ROOT_DIR}"/*)
            printf './%s' "${path#"${ROOT_DIR}/"}"
            ;;
        "")
            printf ''
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
        | sed -E "s/[[:space:]]+#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//; s/^\"//; s/\"$//; s/^'//; s/'$//"
}

validate_version() {
    local label=$1
    local version=$2

    if [[ ! "${version}" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
        die "${label} '${version}' is not valid for Docker tags/file names. Use letters, numbers, underscore, dot, or dash."
    fi
}

validate_image_ref() {
    local label=$1
    local image_ref=$2

    [[ -z "${image_ref}" ]] && return 0
    if [[ ! "${image_ref}" =~ ^[^[:space:]]+:[^[:space:]]+$ ]]; then
        die "${label} image '${image_ref}' must include a Docker tag"
    fi
}

image_repo() {
    local image_ref=$1
    printf '%s' "${image_ref%:*}"
}

image_tag() {
    local image_ref=$1
    printf '%s' "${image_ref##*:}"
}

select_latest_path() {
    local label=$1
    shift
    local matches=()
    local candidate

    for candidate in "$@"; do
        if [[ -d "${candidate}" && -f "${candidate}/install-2-seirios.sh" && -f "${candidate}/files/catkin_ws/movel_ai/docker-compose.yaml" ]]; then
            matches+=("${candidate}")
        fi
    done

    [[ ${#matches[@]} -gt 0 ]] || die "No template found for ${label}"
    printf '%s\n' "${matches[@]}" | sort -V | tail -n 1
}

discover_templates() {
    shopt -s nullglob globstar

    local ros2_template_root="ros2"
    local ros2_template_label="ROS2"
    if [[ "${ROS2_VERSION:-}${ROS2_CONFIG_VERSION:-}" == *-jazzy* ]]; then
        ros2_template_root="ros2-jazzy"
        ros2_template_label="ROS2 Jazzy"
    fi

    ROS1_X86_TEMPLATE="${ROS1_X86_TEMPLATE:-$(select_latest_path "ROS1 x86" "${ROOT_DIR}"/templates/ros1/x86/easy-deploy "${ROOT_DIR}"/movel-ai-easy-deploy-x86_64-*/**/easy-deploy)}"
    ROS1_ARM64_TEMPLATE="${ROS1_ARM64_TEMPLATE:-$(select_latest_path "ROS1 arm64" "${ROOT_DIR}"/templates/ros1/arm64/easy-deploy "${ROOT_DIR}"/movel-ai-easy-deploy-arm64-*/**/easy-deploy)}"
    ROS2_X86_TEMPLATE="${ROS2_X86_TEMPLATE:-$(select_latest_path "${ros2_template_label} x86" "${ROOT_DIR}"/templates/${ros2_template_root}/x86/easy-deploy)}"
    ROS2_ARM64_TEMPLATE="${ROS2_ARM64_TEMPLATE:-$(select_latest_path "${ros2_template_label} arm64" "${ROOT_DIR}"/templates/${ros2_template_root}/arm64/easy-deploy)}"

    shopt -u nullglob globstar
}

manifest_get_simple() {
    local file=$1
    local section=$2
    local key=$3
    local current=""
    local line=""

    [[ -f "${file}" ]] || return 0

    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line%$'\r'}"
        [[ "${line}" =~ ^[[:space:]]*($|#) ]] && continue

        if [[ "${line}" =~ ^([A-Za-z0-9_-]+):[[:space:]]*$ ]]; then
            current="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ "${current}" == "${section}" && "${line}" =~ ^[[:space:]][[:space:]]([A-Za-z0-9_-]+):[[:space:]]*(.*)$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "${key}" ]]; then
                strip_yaml_value "${BASH_REMATCH[2]}"
                return 0
            fi
        fi
    done < "${file}"
}

manifest_get_image() {
    local file=$1
    local arch=$2
    local key=$3
    local in_images=0
    local current_arch=""
    local line=""

    [[ -f "${file}" ]] || return 0

    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line%$'\r'}"
        [[ "${line}" =~ ^[[:space:]]*($|#) ]] && continue

        if [[ "${line}" =~ ^images:[[:space:]]*$ ]]; then
            in_images=1
            current_arch=""
            continue
        fi

        if [[ ${in_images} -eq 1 && "${line}" =~ ^[A-Za-z0-9_-]+:[[:space:]]*$ ]]; then
            in_images=0
            current_arch=""
            continue
        fi

        if [[ ${in_images} -eq 1 && "${line}" =~ ^[[:space:]][[:space:]]([A-Za-z0-9_-]+):[[:space:]]*$ ]]; then
            current_arch="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ ${in_images} -eq 1 && "${current_arch}" == "${arch}" && "${line}" =~ ^[[:space:]][[:space:]][[:space:]][[:space:]]([A-Za-z0-9_-]+):[[:space:]]*(.*)$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "${key}" ]]; then
                strip_yaml_value "${BASH_REMATCH[2]}"
                return 0
            fi
        fi
    done < "${file}"
}

resolve_manifest_path() {
    local manifest_file=$1
    local configured_path=$2
    local base_dir

    [[ -n "${configured_path}" ]] || return 0

    case "${configured_path}" in
        /*)
            printf '%s' "${configured_path}"
            ;;
        ./*)
            printf '%s/%s' "${ROOT_DIR}" "${configured_path#./}"
            ;;
        *)
            base_dir=$(cd "$(dirname "${manifest_file}")" && pwd)
            printf '%s/%s' "${base_dir}" "${configured_path}"
            ;;
    esac
}

resolve_config_dir() {
    local manifest_file=$1
    local fallback_dir=$2
    local manifest_config

    manifest_config=$(manifest_get_simple "${manifest_file}" "config" "path")
    if [[ -n "${manifest_config}" ]]; then
        resolve_manifest_path "${manifest_file}" "${manifest_config}"
    else
        printf '%s' "${fallback_dir}"
    fi
}

resolve_bundle_id() {
    local manifest_file=$1
    local config_dir=$2
    local override_version=$3
    local bundle_id

    if [[ -n "${override_version}" ]]; then
        printf '%s' "${override_version}"
        return 0
    fi

    bundle_id=$(manifest_get_simple "${manifest_file}" "bundle" "id")
    if [[ -n "${bundle_id}" ]]; then
        printf '%s' "${bundle_id}"
    else
        read_config_version "${config_dir}"
    fi
}

apply_manifest_author() {
    local manifest_author

    [[ ${AUTHOR_SET} -eq 0 ]] || return 0

    manifest_author=$(manifest_get_simple "${ROS1_MANIFEST}" "bundle" "author")
    if [[ -z "${manifest_author}" ]]; then
        manifest_author=$(manifest_get_simple "${ROS2_MANIFEST}" "bundle" "author")
    fi
    if [[ -n "${manifest_author}" ]]; then
        RELEASE_AUTHOR="${manifest_author}"
    fi
}

validate_manifest_ros() {
    local manifest_file=$1
    local expected_ros=$2
    local manifest_ros

    manifest_ros=$(manifest_get_simple "${manifest_file}" "bundle" "ros")
    if [[ -n "${manifest_ros}" && "${manifest_ros}" != "${expected_ros}" ]]; then
        die "${manifest_file} has bundle.ros=${manifest_ros}, expected ${expected_ros}"
    fi
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

update_image_ref() {
    local package_dir=$1
    local compose_file=$2
    local label=$3
    local image_ref=$4
    local repo tag version_file

    [[ -n "${image_ref}" ]] || return 0
    validate_image_ref "${label}" "${image_ref}"
    repo=$(image_repo "${image_ref}")
    tag=$(image_tag "${image_ref}")

    update_compose_image "${compose_file}" "${repo}" "${tag}"
    for version_file in "${package_dir}"/version_config*.yaml; do
        [[ -e "${version_file}" ]] || continue
        update_yaml_version "${version_file}" "${repo}" "${tag}"
    done
}

write_release_info() {
    local package_dir=$1
    local package_name=$2
    local ros_line=$3
    local arch=$4
    local bundle_id=$5
    local config_version=$6
    local template_dir=$7
    local config_dir=$8
    local manifest_file=$9
    local rns_image=${10}
    local backend_image=${11}
    local frontend_image=${12}
    local backend_worker_image=${13}
    local redis_image=${14}
    local rabbitmq_image=${15}
    local mongo_image=${16}
    local info_file="${package_dir}/release_info.json"

    cat > "${info_file}" <<EOF
{
  "package_name": "$(json_escape "${package_name}")",
  "file_name": "$(json_escape "${package_name}.zip")",
  "author": "$(json_escape "${RELEASE_AUTHOR}")",
  "build_date": "$(json_escape "${BUILD_DATE}")",
  "ros": "$(json_escape "${ros_line}")",
  "bundle_id": "$(json_escape "${bundle_id}")",
  "version": "$(json_escape "${bundle_id}")",
  "config_version": "$(json_escape "${config_version}")",
  "arch": "$(json_escape "${arch}")",
  "docker_compose": "files/catkin_ws/movel_ai/docker-compose.yaml",
  "docker_image": "$(json_escape "${rns_image}")",
  "images": {
    "rns": "$(json_escape "${rns_image}")",
    "backend": "$(json_escape "${backend_image}")",
    "frontend": "$(json_escape "${frontend_image}")",
    "backend_worker": "$(json_escape "${backend_worker_image}")",
    "redis": "$(json_escape "${redis_image}")",
    "rabbitmq": "$(json_escape "${rabbitmq_image}")",
    "mongo": "$(json_escape "${mongo_image}")"
  },
  "config_path": "files/catkin_ws/movel_ai/config",
  "config_source": "$(json_escape "$(relative_path "${config_dir}")")",
  "template_source": "$(json_escape "$(relative_path "${template_dir}")")",
  "manifest_source": "$(json_escape "$(relative_path "${manifest_file}")")"
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
    local bundle_id=$3
    local config_version=$4
    local template_dir=$5
    local config_dir=$6
    local manifest_file=$7
    local rns_image=$8
    local backend_image=$9
    local frontend_image=${10}
    local backend_worker_image=${11}
    local redis_image=${12}
    local rabbitmq_image=${13}
    local mongo_image=${14}

    local service_name rns_repo package_name package_dir config_target compose_file output_zip
    package_name="easy-deploy-${ros_line}-${bundle_id}-${arch}"
    package_dir="${WORK_DIR}/${package_name}"

    if [[ "${ros_line}" == "ros1" ]]; then
        service_name="seirios-ros"
        rns_repo="movelrobots/rns-ros"
    else
        service_name="seirios-ros2"
        rns_repo="movelrobots/rns-ros2"
    fi
    rns_image="${rns_image:-${rns_repo}:${config_version}}"

    validate_version "${ros_line} bundle id" "${bundle_id}"
    validate_version "${ros_line} config version" "${config_version}"

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
    update_release_version_file "${config_target}/seirios_config_release.yml" "${config_version}"

    printf '%s\n' "${arch}" > "${package_dir}/ARCH.txt"
    printf '%s\n' "${BUILD_DATE}" > "${package_dir}/PACKAGE_DATE.txt"

    compose_file="${package_dir}/files/catkin_ws/movel_ai/docker-compose.yaml"
    update_image_ref "${package_dir}" "${compose_file}" "rns" "${rns_image}"
    update_image_ref "${package_dir}" "${compose_file}" "backend" "${backend_image}"
    update_image_ref "${package_dir}" "${compose_file}" "frontend" "${frontend_image}"
    update_image_ref "${package_dir}" "${compose_file}" "backend_worker" "${backend_worker_image}"
    update_image_ref "${package_dir}" "${compose_file}" "redis" "${redis_image}"
    update_image_ref "${package_dir}" "${compose_file}" "rabbitmq" "${rabbitmq_image}"
    update_image_ref "${package_dir}" "${compose_file}" "mongo" "${mongo_image}"

    if ! grep -q "${service_name}:" "${compose_file}"; then
        die "${package_name}: expected service ${service_name} in ${compose_file}"
    fi

    enable_config_overwrite "${package_dir}/install/install_catkin_ws.sh"
    write_release_info \
        "${package_dir}" "${package_name}" "${ros_line}" "${arch}" "${bundle_id}" "${config_version}" \
        "${template_dir}" "${config_dir}" "${manifest_file}" \
        "${rns_image}" "${backend_image}" "${frontend_image}" "${backend_worker_image}" \
        "${redis_image}" "${rabbitmq_image}" "${mongo_image}"

    output_zip="${DIST_DIR}/${package_name}.zip"
    rm -f "${output_zip}"
    (cd "${WORK_DIR}" && zip -qr "${output_zip}" "${package_name}")
    log "Created ${output_zip}"
}

write_manifest() {
    local manifest_file="${DIST_DIR}/manifest.json"
    local assets=""
    local comma=""

    if [[ ${ROS1_IN_SCOPE} -eq 1 ]]; then
        assets+="${comma}    {
      \"ros\": \"ros1\",
      \"bundle_id\": \"${ROS1_VERSION}\",
      \"config_version\": \"${ROS1_CONFIG_VERSION}\",
      \"arch\": \"x86\",
      \"file\": \"easy-deploy-ros1-${ROS1_VERSION}-x86.zip\",
      \"github_release_tag\": \"ros1-${ROS1_VERSION}\"
    },
    {
      \"ros\": \"ros1\",
      \"bundle_id\": \"${ROS1_VERSION}\",
      \"config_version\": \"${ROS1_CONFIG_VERSION}\",
      \"arch\": \"arm64\",
      \"file\": \"easy-deploy-ros1-${ROS1_VERSION}-arm64.zip\",
      \"github_release_tag\": \"ros1-${ROS1_VERSION}\"
    }"
        comma=$',\n'
    fi

    if [[ ${ROS2_IN_SCOPE} -eq 1 ]]; then
        assets+="${comma}    {
      \"ros\": \"ros2\",
      \"bundle_id\": \"${ROS2_VERSION}\",
      \"config_version\": \"${ROS2_CONFIG_VERSION}\",
      \"arch\": \"x86\",
      \"file\": \"easy-deploy-ros2-${ROS2_VERSION}-x86.zip\",
      \"github_release_tag\": \"ros2-${ROS2_VERSION}\"
    },
    {
      \"ros\": \"ros2\",
      \"bundle_id\": \"${ROS2_VERSION}\",
      \"config_version\": \"${ROS2_CONFIG_VERSION}\",
      \"arch\": \"arm64\",
      \"file\": \"easy-deploy-ros2-${ROS2_VERSION}-arm64.zip\",
      \"github_release_tag\": \"ros2-${ROS2_VERSION}\"
    }"
        comma=$',\n'
    fi

    cat > "${manifest_file}" <<EOF
{
  "generated_at": "$(date -Iseconds)",
  "author": "$(json_escape "${RELEASE_AUTHOR}")",
  "assets": [
${assets}
  ]
}
EOF
    log "Created ${manifest_file}"
}

ROS1_VERSION=""
ROS2_VERSION=""
ROS1_CONFIG_VERSION=""
ROS2_CONFIG_VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ros1-manifest)
            ROS1_MANIFEST=$2
            shift 2
            ;;
        --ros2-manifest)
            ROS2_MANIFEST=$2
            shift 2
            ;;
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
            AUTHOR_SET=1
            shift 2
            ;;
        --deploy-for)
            DEPLOY_FOR=$2
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

require_command grep
require_command sed
require_command sort
require_command zip

case "${DEPLOY_FOR}" in
    ros1|ros2|both) ;;
    *) die "--deploy-for must be one of: ros1, ros2, both (got '${DEPLOY_FOR}')" ;;
esac

ROS1_IN_SCOPE=0
ROS2_IN_SCOPE=0
[[ "${DEPLOY_FOR}" == "ros1" || "${DEPLOY_FOR}" == "both" ]] && ROS1_IN_SCOPE=1
[[ "${DEPLOY_FOR}" == "ros2" || "${DEPLOY_FOR}" == "both" ]] && ROS2_IN_SCOPE=1

if [[ ${ROS1_IN_SCOPE} -eq 1 ]]; then
    validate_manifest_ros "${ROS1_MANIFEST}" "ros1"
fi
if [[ ${ROS2_IN_SCOPE} -eq 1 ]]; then
    validate_manifest_ros "${ROS2_MANIFEST}" "ros2"
fi
apply_manifest_author

if [[ ${ROS1_IN_SCOPE} -eq 1 ]]; then
    ROS1_CONFIG_DIR=$(resolve_config_dir "${ROS1_MANIFEST}" "${ROS1_CONFIG_DIR}")
    ROS1_CONFIG_VERSION=$(read_config_version "${ROS1_CONFIG_DIR}")
    ROS1_VERSION=$(resolve_bundle_id "${ROS1_MANIFEST}" "${ROS1_CONFIG_DIR}" "${ROS1_VERSION}")
fi
if [[ ${ROS2_IN_SCOPE} -eq 1 ]]; then
    ROS2_CONFIG_DIR=$(resolve_config_dir "${ROS2_MANIFEST}" "${ROS2_CONFIG_DIR}")
    ROS2_CONFIG_VERSION=$(read_config_version "${ROS2_CONFIG_DIR}")
    ROS2_VERSION=$(resolve_bundle_id "${ROS2_MANIFEST}" "${ROS2_CONFIG_DIR}" "${ROS2_VERSION}")
fi
BUILD_DATE="$(date -Iseconds)"

if [[ ${ROS1_IN_SCOPE} -eq 1 ]]; then
    [[ -n "${ROS1_VERSION}" ]] || die "Could not read ROS1 bundle id"
    validate_version "ROS1 bundle id" "${ROS1_VERSION}"
    validate_version "ROS1 config version" "${ROS1_CONFIG_VERSION}"
fi
if [[ ${ROS2_IN_SCOPE} -eq 1 ]]; then
    [[ -n "${ROS2_VERSION}" ]] || die "Could not read ROS2 bundle id"
    validate_version "ROS2 bundle id" "${ROS2_VERSION}"
    validate_version "ROS2 config version" "${ROS2_CONFIG_VERSION}"
fi

discover_templates

log "Deploy target: ${DEPLOY_FOR}"
if [[ ${ROS1_IN_SCOPE} -eq 1 ]]; then
    log "ROS1 bundle id: ${ROS1_VERSION}"
    log "ROS1 config version: ${ROS1_CONFIG_VERSION}"
    log "ROS1 manifest: $(relative_path "${ROS1_MANIFEST}")"
    log "ROS1 x86 template: ${ROS1_X86_TEMPLATE}"
    log "ROS1 arm64 template: ${ROS1_ARM64_TEMPLATE}"
fi
if [[ ${ROS2_IN_SCOPE} -eq 1 ]]; then
    log "ROS2 bundle id: ${ROS2_VERSION}"
    log "ROS2 config version: ${ROS2_CONFIG_VERSION}"
    log "ROS2 manifest: $(relative_path "${ROS2_MANIFEST}")"
    log "ROS2 x86 template: ${ROS2_X86_TEMPLATE}"
    log "ROS2 arm64 template: ${ROS2_ARM64_TEMPLATE}"
fi
log "Release author: ${RELEASE_AUTHOR}"
log "Build date: ${BUILD_DATE}"

# Normalize DIST_DIR/WORK_DIR to absolute paths. The zip step cd's into
# WORK_DIR before writing output_zip, so a relative DIST_DIR (e.g. "dist")
# would resolve against the wrong directory and fail with "Could not create
# output file".
case "${DIST_DIR}" in
    /*) ;;
    *) DIST_DIR="${PWD}/${DIST_DIR}" ;;
esac
case "${WORK_DIR}" in
    /*) ;;
    *) WORK_DIR="${PWD}/${WORK_DIR}" ;;
esac

mkdir -p "${DIST_DIR}" "${WORK_DIR}"

if [[ ${ROS1_IN_SCOPE} -eq 1 ]]; then
    build_package \
        "ros1" "x86" "${ROS1_VERSION}" "${ROS1_CONFIG_VERSION}" "${ROS1_X86_TEMPLATE}" "${ROS1_CONFIG_DIR}" "${ROS1_MANIFEST}" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "x86" "rns")" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "x86" "backend")" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "x86" "frontend")" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "x86" "backend_worker")" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "x86" "redis")" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "x86" "rabbitmq")" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "x86" "mongo")"

    build_package \
        "ros1" "arm64" "${ROS1_VERSION}" "${ROS1_CONFIG_VERSION}" "${ROS1_ARM64_TEMPLATE}" "${ROS1_CONFIG_DIR}" "${ROS1_MANIFEST}" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "arm64" "rns")" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "arm64" "backend")" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "arm64" "frontend")" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "arm64" "backend_worker")" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "arm64" "redis")" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "arm64" "rabbitmq")" \
        "$(manifest_get_image "${ROS1_MANIFEST}" "arm64" "mongo")"
fi

if [[ ${ROS2_IN_SCOPE} -eq 1 ]]; then
    build_package \
        "ros2" "x86" "${ROS2_VERSION}" "${ROS2_CONFIG_VERSION}" "${ROS2_X86_TEMPLATE}" "${ROS2_CONFIG_DIR}" "${ROS2_MANIFEST}" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "x86" "rns")" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "x86" "backend")" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "x86" "frontend")" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "x86" "backend_worker")" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "x86" "redis")" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "x86" "rabbitmq")" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "x86" "mongo")"

    build_package \
        "ros2" "arm64" "${ROS2_VERSION}" "${ROS2_CONFIG_VERSION}" "${ROS2_ARM64_TEMPLATE}" "${ROS2_CONFIG_DIR}" "${ROS2_MANIFEST}" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "arm64" "rns")" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "arm64" "backend")" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "arm64" "frontend")" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "arm64" "backend_worker")" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "arm64" "redis")" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "arm64" "rabbitmq")" \
        "$(manifest_get_image "${ROS2_MANIFEST}" "arm64" "mongo")"
fi

write_manifest

log "Done. Upload the zip files in ${DIST_DIR} to GitHub Releases."
