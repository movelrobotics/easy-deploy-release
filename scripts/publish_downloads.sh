#!/usr/bin/env bash
#
# publish_downloads.sh — publish/update Easy Deploy download entries on the
# Movél website via the internal downloads API, driven by release-config.yml.
#
# For each release line in scope (deploy_for), this reads the <section>.download
# block and <section>.version, derives `repo` and `releasePath` from the release
# tag, and creates or updates the entry keyed by `slug`.
#
# API contract (verified against the deployed API):
#   - Auth is a dedicated API key sent as the `x-api-key` header, scoped to
#     /api/internal/downloads only. Bearer auth is NOT accepted.
#   - GET    /api/internal/downloads        -> list ({"packages":[...]})
#   - POST   /api/internal/downloads        -> create; re-POSTing an existing
#                                             slug fails with HTTP 500, so
#                                             POST is create-only.
#   - PUT    /api/internal/downloads/<slug> -> update; unknown slug is 404.
#   - DELETE requires an SSO session (not available to this key).
# Because POST is not an upsert, idempotency is implemented here: fetch the
# list once, then PUT when the slug already exists and POST when it does not.
#
# Env:
#   MOVEL_API_BASE_URL  API base, e.g. https://api.movelrobotics.com
#   MOVEL_API_TOKEN     downloads API key (REQUIRED). Long-lived key deployed
#                       on the server; do NOT commit it anywhere.

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

# Expand deploy_for into the ordered list of release-line sections in scope.
# Sections: ros1, ros2 (default ROS2 = Humble), ros2_jazzy.
sections_for() {
    # sections_for <deploy_for>
    local deploy_for=$1
    case "${deploy_for}" in
        ros1)          echo "ros1" ;;
        ros2)          echo "ros2" ;;
        ros2_jazzy)    echo "ros2_jazzy" ;;
        both)          echo "ros1 ros2" ;;
        all)           echo "ros1 ros2 ros2_jazzy" ;;
        "")            die "release-config.yml is missing 'deploy_for'" ;;
        *)
            # Comma-separated list, e.g. "ros1,ros2_jazzy".
            local parts=(${deploy_for//,/ }) part
            [[ ${#parts[@]} -gt 0 ]] || die "Invalid deploy_for: '${deploy_for}'"
            for part in "${parts[@]}"; do
                case "${part}" in
                    ros1|ros2|ros2_jazzy) ;;
                    *) die "deploy_for lines must be ros1, ros2, or ros2_jazzy (got '${part}')" ;;
                esac
            done
            echo "${parts[*]}"
            ;;
    esac
}

publish_section() {
    # publish_section <section> <existing_slugs>
    local section=$1
    local existing_slugs=$2
    local version build tag slug payload http_code body

    version=$(yq_read ".${section}.version")
    [[ -n "${version}" ]] || die "release-config.yml is missing '${section}.version'"

    # Build line defaults to the section name; ros2_jazzy overrides to ros2 so
    # the GitHub tag keeps the historical ros2-bundle-* prefix.
    build=$(yq_read ".${section}.build")
    [[ -n "${build}" ]] || build="${section}"
    case "${build}" in
        ros1|ros2) ;;
        *) die "${section}.build must be ros1 or ros2 (got '${build}')" ;;
    esac

    # Tag mirrors scripts/release.sh: ${build}-${bundle_id}, bundle_id=bundle-<version>
    tag="${build}-bundle-${version}"

    # Emit the configured download block as JSON, then inject derived fields.
    # Keys mirror the API contract so no mapping layer is needed.
    if ! payload=$("${YQ}" eval -o=json ".${section}.download" "${CONFIG_FILE}" 2>/dev/null) \
        || [[ -z "${payload}" || "${payload}" == "null" ]]; then
        die "release-config.yml is missing '${section}.download' (slug/name/etc) for ${section}"
    fi
    slug=$(printf '%s' "${payload}" | jq -r '.slug // empty')
    [[ -n "${slug}" ]] || die "${section}.download.slug is empty"

    payload=$(printf '%s' "${payload}" \
        | jq --arg repo "${RELEASE_REPO_URL}" \
             --arg releasePath "/releases/tag/${tag}" \
             '. + {repo:$repo, releasePath:$releasePath, dependenciesVersion:(.dependenciesVersion // {})}')

    local method url
    if grep -qx "${slug}" <<<"${existing_slugs}"; then
        method="PUT"
        url="${API_ENDPOINT}/${slug}"
    else
        method="POST"
        url="${API_ENDPOINT}"
    fi

    log "Publishing ${section} -> ${method} ${slug}"
    log "  repo=${RELEASE_REPO_URL}"
    log "  releasePath=/releases/tag/${tag}"

    http_code=$(printf '%s' "${payload}" \
        | curl -sS -o /tmp/publish_downloads_resp.$$ -w '%{http_code}' \
            -X "${method}" "${url}" \
            -H "Content-Type: application/json" \
            -H "x-api-key: ${API_TOKEN}" \
            --data @-) || die "curl request to ${url} failed for ${section}"
    body=$(cat /tmp/publish_downloads_resp.$$ 2>/dev/null || true)
    rm -f /tmp/publish_downloads_resp.$$

    if [[ "${http_code}" =~ ^2 ]]; then
        log "  ${section}/${slug}: ${method} HTTP ${http_code} OK"
    else
        log "  response: ${body}"
        die "${section}: downloads API returned HTTP ${http_code} for ${method} ${url}"
    fi
}

[[ -f "${CONFIG_FILE}" ]] || die "release-config.yml not found at ${CONFIG_FILE}"
require_command jq
require_command curl
ensure_yq

DEPLOY_FOR=$(yq_read '.deploy_for')
SECTIONS=$(sections_for "${DEPLOY_FOR}")

log "Base URL: ${BASE_URL}"
log "Deploy target: ${DEPLOY_FOR} (${SECTIONS// /, })"

# One GET up front: the slug list decides PUT (update) vs POST (create) per line.
log "Fetching current download entries..."
EXISTING_SLUGS=$(curl -sS -f -m 30 \
    -H "x-api-key: ${API_TOKEN}" \
    "${API_ENDPOINT}" \
    | jq -r '.packages[].slug') \
    || die "Failed to list existing download entries from ${API_ENDPOINT}"

for section in ${SECTIONS}; do
    publish_section "${section}" "${EXISTING_SLUGS}"
done

log "Done. Download entries published to ${API_ENDPOINT}"
