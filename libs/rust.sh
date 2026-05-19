#!/usr/bin/env bash
# Rust and Cargo helpers.

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2317

if [[ -n "${LINUX_CONFIGS_LIBS_RUST_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

LINUX_CONFIGS_LIBS_RUST_LOADED=1

prepend_cargo_bin_to_path() {
    [[ -d "${HOME}/.cargo/bin" ]] || return 0
    case ":${PATH}:" in
    *:"${HOME}/.cargo/bin":*) return 0 ;;
    esac
    export PATH="${HOME}/.cargo/bin:${PATH}"
}

encode_rustflags() {
    local separator=$'\x1f'
    local encoded=''
    local flag

    for flag in "$@"; do
        [[ -z "${encoded}" ]] || encoded+="${separator}"
        encoded+="${flag}"
    done

    printf '%s' "${encoded}"
}

exec_with_encoded_rustflags() {
    local rustflags_name="${1:-rustflags}"
    local rustflags_value
    shift || true

    if (($# == 0)); then
        log_error 'Missing command.'
        exit 1
    fi

    eval "rustflags_value=\"\${${rustflags_name}[*]-}\""
    if [[ -z "${rustflags_value}" ]]; then
        exec "$@"
    fi

    eval "exec env CARGO_ENCODED_RUSTFLAGS=\"\$(encode_rustflags \"\${${rustflags_name}[@]}\")\" \"\$@\""
}

ensure_cargo_target() {
    local target="$1"

    require_cmd rustup grep
    rustup target list --installed | grep -Fxq "${target}" || rustup target add "${target}"
}

require_cargo_zigbuild() {
    require_cmd cargo-zigbuild zig
}
