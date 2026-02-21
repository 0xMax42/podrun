#!/usr/bin/env bash
set -euo pipefail

verbose=${VERBOSE:-0}

run_opts=()
container_args=()
image=""

# Everything before -- belongs to podman
while [[ $# -gt 0 ]]; do
    case "$1" in
    --)
        shift
        image="${1:?IMAGE missing after --}"
        shift
        container_args=("$@")
        break
        ;;
    *)
        run_opts+=("$1")
        shift
        ;;
    esac
done

if [[ -z "${image}" ]]; then
    echo "usage: podrun [podman-run-options...] -- IMAGE [container-args...]" >&2
    exit 1
fi

# -------------------------------
# Log helper
# -------------------------------

log_info() {
    if [[ "${verbose}" -eq 0 ]]; then
        return
    fi
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

# -----------------------------
# Determine build unit name
# -----------------------------

derive_unit_name() {
    local img="$1"

    # strip registry
    local name="${img##*/}"
    # strip tag
    name="${name%%:*}"

    echo "${name}-build.service"
}

# -----------------------------
# Extract INVARIANCE_HASH from systemd unit
# -----------------------------

get_unit_hash() {
    local unit="$1"

    local env_line
    env_line="$(systemctl --user show -p Environment --value "${unit}" 2>/dev/null || true)"

    if [[ -z "${env_line}" ]]; then
        return 0
    fi

    # extract INVARIANCE_HASH=...
    for token in ${env_line}; do
        if [[ "${token}" == INVARIANCE_HASH=* ]]; then
            echo "${token#INVARIANCE_HASH=}"
            return 0
        fi
    done
}

# -----------------------------
# Extract hash from image label
# -----------------------------

get_image_hash() {
    local img="$1"

    podman image inspect "${img}" \
        --format '{{ index .Config.Labels "io.0xmax42.invariance-hash" }}' \
        2>/dev/null || true
}

# -----------------------------
# Main logic
# -----------------------------

unit="$(derive_unit_name "${image}")"

need_build=false

if ! podman image exists "${image}" >/dev/null 2>&1; then
    need_build=true
else
    unit_hash="$(get_unit_hash "${unit}")"
    image_hash="$(get_image_hash "${image}")"

    # If either side is missing -> rebuild
    if [[ -z "${unit_hash}" || -z "${image_hash}" ]]; then
        log_info "Invariance hash missing."
        log_info "Unit : ${unit_hash:-<none>}"
        log_info "Image: ${image_hash:-<none>}"
        need_build=true

    elif [[ "${unit_hash}" != "${image_hash}" ]]; then
        log_info "Invariance hash mismatch."
        log_info "Unit : ${unit_hash}"
        log_info "Image: ${image_hash}"
        need_build=true
    fi
fi

if [[ "${need_build}" == true ]]; then
    log_info "Triggering build via ${unit}"

    if ! systemctl --user start "${unit}"; then
        exit_code=$?
        # 5 - not exist
        if [[ "${exit_code}" -eq 5 ]]; then
            log_error "Build unit ${unit} does not exist."
            exit 5
        fi
        log_error "Build failed."
        journalctl --user -u "${unit}" -n 50 --no-pager >&2 || true
        exit "${exit_code}"
    fi
fi

exec podman run \
    "${run_opts[@]}" \
    "${image}" \
    "${container_args[@]}"
