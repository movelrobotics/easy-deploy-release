#!/usr/bin/env bash
#
# release.sh — orchestrates an Easy Deploy release from the single source of
# truth (release-config.yml).
#
# Flow:
#   1. Read release-config.yml (deploy_for, author, per-ros config ref + images).
#   2. Clone the matching config repos at the configured branch/tag.
#   3. Render per-ros manifests (without config.path) for the proven builder.
#   4. Run build_easy_deploy_release.sh --deploy-for ... (only the in-scope line(s)).
#   5. Upload the produced zips to GitHub Releases (skip with --no-upload).
#
# If release-config.yml is absent, this script falls back to the legacy path
# and simply runs build_easy_deploy_release.sh with whatever extra args are
# passed, so existing local workflows keep working unchanged.

set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
CONFIG_FILE="${ROOT_DIR}/release-config.yml"
BUILDER="${SCRIPT_DIR}/build_easy_deploy_release.sh"

CONFIG_REPO_ROS1="movelrobotics/rns-config"
CONFIG_REPO_ROS2="movelrobotics/rns-config2"
RELEASE_REPO="movelrobotics/easy-deploy-release"

DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
RELEASE_WORK="${RELEASE_WORK:-${ROOT_DIR}/.release}"
CONFIGS_DIR="${RELEASE_WORK}/configs"
RENDER_DIR="${RELEASE_WORK}/manifests"

DEPLOY_FOR_OVERRIDE=""
NO_UPLOAD=0
KEEP_CONFIG=0
EXTRA_ARGS=()

usage() {
    cat <<'EOF'
Usage:
  scripts/release.sh [options] [-- builder-options...]

Drives an Easy Deploy release from release-config.yml.

Options:
  --deploy-for TARGET   ros1 | ros2 | both. Overrides release-config.yml.
  --dist-dir DIR        Output directory. Default: ./dist
  --no-upload           Build zips only; do not push to GitHub Releases.
  --keep-config         Reuse an existing cloned config dir (skip re-clone).
  --help, -h            Show this help.

Environment:
  GITHUB_USER / GITHUB_TOKEN   Used to clone private config repos and to
                               authenticate gh (GH_TOKEN). Required in CI for
                               private repos; locally you may rely on git
                               credentials / SSH instead.

Any args after the recognized options are forwarded to build_easy_deploy_release.sh.
EOF
}

log() {
    printf '[release] %s\n' "$*"
}

die() {
    printf '[release] ERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

# Resolve a usable yq (mikefarah/yq v4). Prefer system yq; otherwise download a
# static binary into the work dir and cache it.
ensure_yq() {
    # A yq is "good enough" if it can eval against real input the way yq_read
    # uses it (no -r shorthand, since some shipped builds reject it). Guard each
    # probe with command -v / -x BEFORE invoking yq so a missing binary does not
    # trip `set -e`/pipefail.
    local bin_dir="${RELEASE_WORK}/.bin"
    local yq_bin="${bin_dir}/yq"
    local probe

    if command -v yq >/dev/null 2>&1; then
        probe=$(printf 'a: ok\n' | yq eval '.a' - 2>/dev/null || true)
        if [[ "${probe}" == "ok" ]]; then
            YQ="yq"
            return 0
        fi
    fi

    if [[ -x "${yq_bin}" ]]; then
        probe=$(printf 'a: ok\n' | "${yq_bin}" eval '.a' - 2>/dev/null || true)
        if [[ "${probe}" == "ok" ]]; then
            YQ="${yq_bin}"
            return 0
        fi
    fi

    require_command curl
    mkdir -p "${bin_dir}"
    local arch
    case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) die "Unsupported architecture for yq auto-install: $(uname -m)" ;;
    esac
    local version="v4.44.3"
    local url="https://github.com/mikefarah/yq/releases/download/${version}/yq_linux_${arch}"
    log "Downloading yq ${version} (${arch})..."
    curl -fsSL "${url}" -o "${yq_bin}" || die "Failed to download yq"
    chmod +x "${yq_bin}"
    YQ="${yq_bin}"
}

yq_read() {
    # yq_read <path>  -> prints value, empty string if missing
    # NOTE: no -r flag. unwrapScalar defaults to true so scalars are unquoted,
    # and some shipped yq builds do not support the -r shorthand.
    "${YQ}" eval "${1} // \"\"" "${CONFIG_FILE}"
}

clone_url() {
    # clone_url <org/repo>   token URL if creds present, else plain https
    local repo=$1
    if [[ -n "${GITHUB_USER:-${GITHUB_TOKEN:-}}" && -n "${GITHUB_TOKEN:-}" ]]; then
        printf 'https://%s:%s@github.com/%s.git' "${GITHUB_USER}" "${GITHUB_TOKEN}" "${repo}"
    else
        printf 'https://github.com/%s.git' "${repo}"
    fi
}

clone_config() {
    # clone_config <ros> <repo> <ref> <target_dir>
    local ros=$1
    local repo=$2
    local ref=$3
    local target=$4

    if [[ ${KEEP_CONFIG} -eq 1 && -f "${target}/seirios_config_release.yml" ]]; then
        log "Keeping existing ${ros} config at ${target} (--keep-config)"
        return 0
    fi

    log "Cloning ${repo} @ ${ref} for ${ros}"
    rm -rf "${target}"
    mkdir -p "${target}"
    if ! git clone --depth 1 --branch "${ref}" "$(clone_url "${repo}")" "${target}" 2>/dev/null; then
        # Remove the partial clone (incl. any .git/config holding the token URL) before failing.
        rm -rf "${target}"
        die "Failed to clone ${repo}@${ref}. Check the ref and your GITHUB_USER/GITHUB_TOKEN."
    fi
    rm -rf "${target}/.git"
}

render_manifest() {
    # render_manifest <ros> <bundle_id> <author> <out_file>
    # Emits a manifest without config.path so the builder honors --ros-config-dir.
    local ros=$1
    local bundle_id=$2
    local author=$3
    local out_file=$4

    {
        printf 'bundle:\n'
        printf '  id: %s\n' "${bundle_id}"
        printf '  ros: %s\n' "${ros}"
        printf '  author: %s\n' "${author}"
        printf 'images:\n'
        printf '  x86:\n'
        "${YQ}" eval ".${ros}.x86" "${CONFIG_FILE}" | sed 's/^/    /'
        printf '  arm64:\n'
        "${YQ}" eval ".${ros}.arm64" "${CONFIG_FILE}" | sed 's/^/    /'
    } > "${out_file}"
}

read_config_version() {
    # read_config_version <config_dir> -> Version: value from seirios_config_release.yml
    local config_dir=$1
    local release_file="${config_dir}/seirios_config_release.yml"
    [[ -f "${release_file}" ]] || { printf 'unknown'; return; }
    sed -nE 's/^Version:[[:space:]]*//p' "${release_file}" \
        | head -n 1 \
        | sed -E "s/[[:space:]]+#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//; s/^\"//; s/\"$//; s/^'//; s/'$//"
}

format_images() {
    # format_images <ros> -> markdown list of x86 and arm64 images from release-config.yml
    local ros=$1
    local arch key val
    local img_keys=(rns backend frontend backend_worker redis rabbitmq mongo)
    for arch in x86 arm64; do
        printf '**Images (%s):**\n' "${arch}"
        for key in "${img_keys[@]}"; do
            val=$(yq_read ".${ros}.${arch}.${key}")
            printf -- '- %s: `%s`\n' "${key}" "${val}"
        done
        printf '\n'
    done
}

upload_release() {
    # upload_release <ros> <bundle_id> <config_ref> <config_version>
    local ros=$1
    local bundle_id=$2
    local config_ref=$3
    local config_version=$4
    local tag="${ros}-${bundle_id}"
    local zip_x86="${DIST_DIR}/easy-deploy-${ros}-${bundle_id}-x86.zip"
    local zip_arm64="${DIST_DIR}/easy-deploy-${ros}-${bundle_id}-arm64.zip"

    [[ -f "${zip_x86}" ]] || die "Missing expected asset: ${zip_x86}"
    [[ -f "${zip_arm64}" ]] || die "Missing expected asset: ${zip_arm64}"

    require_command gh
    export GH_TOKEN="${GITHUB_TOKEN:?GITHUB_TOKEN is required for upload}"

    local title="Easy Deploy ${ros} ${bundle_id}"
    local generated_at
    generated_at="$(date -Iseconds)"
    # Multi-line release notes: includes version, config ref/version, the full
    # image list per arch, and assets (not only a timestamp, so the published
    # release is self-describing).
    local notes
    notes="$(printf '%s\n' \
        "**${ros}** Easy Deploy bundle **${bundle_id}**" \
        "" \
        "| Field | Value |" \
        "| --- | --- |" \
        "| ROS line | ${ros} |" \
        "| Bundle version | ${bundle_id} |" \
        "| Config repo ref | ${config_ref} |" \
        "| Config version | ${config_version} |" \
        "| Author | ${AUTHOR} |" \
        "| Generated | ${generated_at} |")"
    notes="${notes}

$(format_images "${ros}")

**Assets:**
- \`${zip_x86##*/}\`
- \`${zip_arm64##*/}\`"

    if gh release view "${tag}" --repo "${RELEASE_REPO}" >/dev/null 2>&1; then
        log "Release ${tag} exists; uploading assets (--clobber)"
        gh release upload "${tag}" "${zip_x86}" "${zip_arm64}" \
            --repo "${RELEASE_REPO}" --clobber
        # Refresh notes on re-publish so they reflect the latest version info.
        gh release edit "${tag}" --repo "${RELEASE_REPO}" \
            --notes "${notes}" --title "${title}" >/dev/null
    else
        log "Creating release ${tag}"
        gh release create "${tag}" "${zip_x86}" "${zip_arm64}" \
            --repo "${RELEASE_REPO}" \
            --title "${title}" \
            --notes "${notes}"
    fi

    # Verify both assets actually landed on the release; fail loudly on a
    # partial publish rather than silently reporting success.
    local remote_assets
    remote_assets=$(gh release view "${tag}" --repo "${RELEASE_REPO}" --json assets \
        --jq '.assets[].name' 2>/dev/null || printf '')
    local want
    for want in "${zip_x86##*/}" "${zip_arm64##*/}"; do
        if ! grep -qx "${want}" <<<"${remote_assets}"; then
            die "Upload verification failed: '${want}' not found on release ${tag}"
        fi
    done
    log "Uploaded ${zip_x86##*/}, ${zip_arm64##*/} -> ${RELEASE_REPO}@${tag}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --deploy-for)
            DEPLOY_FOR_OVERRIDE=$2
            shift 2
            ;;
        --dist-dir)
            DIST_DIR=$2
            shift 2
            ;;
        --no-upload)
            NO_UPLOAD=1
            shift
            ;;
        --keep-config)
            KEEP_CONFIG=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --)
            shift
            EXTRA_ARGS+=("$@")
            break
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

require_command git

# Legacy fallback: no source-of-truth file -> run the proven builder directly.
if [[ ! -f "${CONFIG_FILE}" ]]; then
    log "release-config.yml not found; running legacy builder"
    FALLBACK_ARGS=(--dist-dir "${DIST_DIR}")
    [[ -n "${DEPLOY_FOR_OVERRIDE}" ]] && FALLBACK_ARGS+=(--deploy-for "${DEPLOY_FOR_OVERRIDE}")
    exec "${BUILDER}" "${FALLBACK_ARGS[@]}" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
fi

ensure_yq
mkdir -p "${CONFIGS_DIR}" "${RENDER_DIR}" "${DIST_DIR}"

DEPLOY_FOR="${DEPLOY_FOR_OVERRIDE:-$(yq_read '.deploy_for')}"
case "${DEPLOY_FOR}" in
    ros1|ros2|both) ;;
    "") die "release-config.yml is missing 'deploy_for'" ;;
    *) die "release-config.yml deploy_for must be ros1, ros2, or both (got '${DEPLOY_FOR}')" ;;
esac

BUILD_ROS1=0
BUILD_ROS2=0
[[ "${DEPLOY_FOR}" == "ros1" || "${DEPLOY_FOR}" == "both" ]] && BUILD_ROS1=1
[[ "${DEPLOY_FOR}" == "ros2" || "${DEPLOY_FOR}" == "both" ]] && BUILD_ROS2=1

AUTHOR=$(yq_read '.author')
[[ -n "${AUTHOR}" ]] || AUTHOR="Movel AI"

log "Deploy target: ${DEPLOY_FOR}"
log "Author: ${AUTHOR}"

BUILDER_ARGS=(--deploy-for "${DEPLOY_FOR}" --dist-dir "${DIST_DIR}" --author "${AUTHOR}")

if [[ ${BUILD_ROS1} -eq 1 ]]; then
    ROS1_VERSION=$(yq_read '.ros1.version')
    [[ -n "${ROS1_VERSION}" ]] || die "release-config.yml is missing 'ros1.version'"
    ROS1_CONFIG_REF=$(yq_read '.ros1.config')
    [[ -n "${ROS1_CONFIG_REF}" ]] || die "release-config.yml is missing 'ros1.config'"
    ROS1_BUNDLE="bundle-${ROS1_VERSION}"
    ROS1_CONFIG_DIR="${CONFIGS_DIR}/rns-config"

    log "ROS1 bundle id: ${ROS1_BUNDLE}"
    log "ROS1 config ref: ${ROS1_CONFIG_REF}"
    clone_config "ros1" "${CONFIG_REPO_ROS1}" "${ROS1_CONFIG_REF}" "${ROS1_CONFIG_DIR}"
    [[ -f "${ROS1_CONFIG_DIR}/seirios_config_release.yml" ]] \
        || die "Cloned ros1 config has no seirios_config_release.yml (wrong ref?)"

    ROS1_MANIFEST="${RENDER_DIR}/ros1-release.yaml"
    render_manifest "ros1" "${ROS1_BUNDLE}" "${AUTHOR}" "${ROS1_MANIFEST}"
    ROS1_CONFIG_VERSION=$(read_config_version "${ROS1_CONFIG_DIR}")
    log "ROS1 config version: ${ROS1_CONFIG_VERSION}"
    BUILDER_ARGS+=(
        --ros1-manifest "${ROS1_MANIFEST}"
        --ros1-config-dir "${ROS1_CONFIG_DIR}"
    )
fi

if [[ ${BUILD_ROS2} -eq 1 ]]; then
    ROS2_VERSION=$(yq_read '.ros2.version')
    [[ -n "${ROS2_VERSION}" ]] || die "release-config.yml is missing 'ros2.version'"
    ROS2_CONFIG_REF=$(yq_read '.ros2.config')
    [[ -n "${ROS2_CONFIG_REF}" ]] || die "release-config.yml is missing 'ros2.config'"
    ROS2_BUNDLE="bundle-${ROS2_VERSION}"
    ROS2_CONFIG_DIR="${CONFIGS_DIR}/rns-config2"

    log "ROS2 bundle id: ${ROS2_BUNDLE}"
    log "ROS2 config ref: ${ROS2_CONFIG_REF}"
    clone_config "ros2" "${CONFIG_REPO_ROS2}" "${ROS2_CONFIG_REF}" "${ROS2_CONFIG_DIR}"
    [[ -f "${ROS2_CONFIG_DIR}/seirios_config_release.yml" ]] \
        || die "Cloned ros2 config has no seirios_config_release.yml (wrong ref?)"

    ROS2_MANIFEST="${RENDER_DIR}/ros2-release.yaml"
    render_manifest "ros2" "${ROS2_BUNDLE}" "${AUTHOR}" "${ROS2_MANIFEST}"
    ROS2_CONFIG_VERSION=$(read_config_version "${ROS2_CONFIG_DIR}")
    log "ROS2 config version: ${ROS2_CONFIG_VERSION}"
    BUILDER_ARGS+=(
        --ros2-manifest "${ROS2_MANIFEST}"
        --ros2-config-dir "${ROS2_CONFIG_DIR}"
    )
fi

log "Running builder: ${BUILDER##*/} ${BUILDER_ARGS[*]}"
"${BUILDER}" "${BUILDER_ARGS[@]}" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"

if [[ ${NO_UPLOAD} -eq 1 ]]; then
    log "--no-upload set; skipping GitHub Releases upload"
    log "Done. Assets are in ${DIST_DIR}"
    exit 0
fi

if [[ ${BUILD_ROS1} -eq 1 ]]; then
    upload_release "ros1" "${ROS1_BUNDLE}" "${ROS1_CONFIG_REF}" "${ROS1_CONFIG_VERSION}"
fi
if [[ ${BUILD_ROS2} -eq 1 ]]; then
    upload_release "ros2" "${ROS2_BUNDLE}" "${ROS2_CONFIG_REF}" "${ROS2_CONFIG_VERSION}"
fi

# Print a summary with direct URLs to every published release so there is no
# ambiguity about what landed on GitHub (the sidebar only shows "Latest").
log "Published releases:"
{
    [[ ${BUILD_ROS1} -eq 1 ]] && gh release view "ros1-${ROS1_BUNDLE}" --repo "${RELEASE_REPO}" --json url --jq '.url' 2>/dev/null
    [[ ${BUILD_ROS2} -eq 1 ]] && gh release view "ros2-${ROS2_BUNDLE}" --repo "${RELEASE_REPO}" --json url --jq '.url' 2>/dev/null
} | sed 's#^#  - #'

log "Done. Release(s) published to ${RELEASE_REPO}."
