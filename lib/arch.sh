# -*- mode: bash; tab-size: 4; -*-
# arch.sh — Architecture detection for linux-configs-and-scripts
#
# Provides:
#   detect_architecture()  — returns: x86_64 | aarch64 | unsupported
#   is_x86_64()
#   is_aarch64()

detect_architecture() {
    local arch
    arch="$(uname -m)"

    case "${arch}" in
    x86_64)
        echo "x86_64"
        ;;
    aarch64 | arm64)
        echo "aarch64"
        ;;
    *)
        echo "unsupported" >&2
        return 1
        ;;
    esac
}

# Convenience predicates
is_x86_64() { [[ "$(detect_architecture)" == "x86_64" ]]; }
is_aarch64() { [[ "$(detect_architecture)" == "aarch64" ]]; }
