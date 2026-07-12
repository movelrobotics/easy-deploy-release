#!/usr/bin/env bash
#
# publish_downloads.sh — publish/update Easy Deploy download entries on the
# Movél website via the internal downloads API, driven by release-config.yml.
#
# For each ros line in scope (deploy_for: ros1 | ros2 | both), this reads the
# <ros>.download block and <ros>.version, derives `repo` and `releasePath`, and
# POSTs the payload to ${MOVEL_API_BASE_URL}/api/internal/downloads.
#
# NOTE: this assumes the downloads API treats a POST as an upsert keyed by
# `slug` (create-or-update in place). If the API is create-only, switch this to
# a GET-then-PUT/PATCH flow once the contract is confirmed by the API team.
#
# Env:
#   MOVEL_API_BASE_URL  API base, e.g. https://api.movelrobotics.com
#   MOVEL_API_TOKEN     bearer token (REQUIRED). Use a long-lived service token;
#                       the personal JWT in the docs expires in ~24h and is not
#                       suitable for unattended CI.

set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
CONFIG_FILE="${ROOT_DIR}/release-config.yml"

RELEASE_REPO="movelrobotics/easy-deploy-release"
RELEASE_REPO_URL="https://github.com/${RELEASE_REPO}"
BASE_URL="${MOVEL_API_BASE_URL:-https://api.movelrobotics.com}"
API_ENDPOINT="${BASE_URL%/}/api/internal/downloads"
API_TOKEN="${MOVEL_API_TOKEN:?MOVEL_API_TOKEN is required to publish downloads}"

RELEASE_WORK="${RELEASE_WORK:-${ROOT_DIR}/.release}"

log() {
    printf '[publish_downloads] %s\n' "$*"
}

die() {
    printf '[publish_downloads] ERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

# Resolve a usable yq (mikefarah/yq v4). Prefer system yq; otherwise download a
# static binary into the work dir and cache it. Mirrors scripts/release.sh.
ensure_yq() {
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
    "${YQ}" eval "${1} // \"\"" "${CONFIG_FILE}"
}

publish_ros() {
    # publish_ros <ros>
    local ros=$1 version tag payload http_code
    version=$(yq_read ".${ros}.version")
    [[ -n "${version}" ]] || die "release-config.yml is missing '${ros}.version'"

    # tag mirrors scripts/release.sh: ${ros}-${bundle_id}, bundle_id=bundle-<version>
    tag="${ros}-bundle-${version}"

    # Emit the configured download block as JSON, then inject derived fields.
    # Keys mirror the API contract so no mapping layer is needed.
    if ! payload=$("${YQ}" eval -o=json ".${ros}.download" "${CONFIG_FILE}" 2>/dev/null) \
        || [[ -z "${payload}" || "${payload}" == "null" ]]; then
        die "release-config.yml is missing '${ros}.download' (slug/name/etc) for ${ros}"
    fi

    log "Publishing ${ros} -> ${API_ENDPOINT}"
    log "  repo=${RELEASE_REPO_URL}"
    log "  releasePath=/releases/tag/${tag}"

    http_code=$(printf '%s' "${payload}" \
        | jq --arg repo "${RELEASE_REPO_URL}" \
             --arg releasePath "/releases/tag/${tag}" \
             '. + {repo:$repo, releasePath:$releasePath, dependenciesVersion:(.dependenciesVersion // {})}' \
        | curl -sS -o /dev/null -w '%{http_code}' \
            -X POST "${API_ENDPOINT}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${API_TOKEN}" \
            --data @-) || die "curl request to ${API_ENDPOINT} failed for ${ros}"

    if [[ "${http_code}" =~ ^2 ]]; then
        log "  ${ros}: HTTP ${http_code} OK"
    else
        die "${ros}: downloads API returned HTTP ${http_code} for ${API_ENDPOINT}"
    fi
}

[[ -f "${CONFIG_FILE}" ]] || die "release-config.yml not found at ${CONFIG_FILE}"
require_command jq
require_command curl
ensure_yq

DEPLOY_FOR=$(yq_read '.deploy_for')
case "${DEPLOY_FOR}" in
    ros1|ros2|both) ;;
    "") die "release-config.yml is missing 'deploy_for'" ;;
    *) die "release-config.yml deploy_for must be ros1, ros2, or both (got '${DEPLOY_FOR}')" ;;
esac

log "Base URL: ${BASE_URL}"
log "Deploy target: ${DEPLOY_FOR}"

# Two separate cases so `both` publishes ros1 then ros2.
case "${DEPLOY_FOR}" in
    ros1|both) publish_ros ros1 ;;
esac
case "${DEPLOY_FOR}" in
    ros2|both) publish_ros ros2 ;;
esac

log "Done. Download entries published to ${API_ENDPOINT}"
