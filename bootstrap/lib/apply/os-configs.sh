# os-configs.sh — Apply OS-specific + shared configs
#
# conf/shared/  — files identical across all OSes (e.g. sshd_config)
# conf/<os>/    — OS-specific overrides
#
# Both are applied: shared first, then OS-specific (OS takes precedence).
# Each file's relative path under the source dir becomes the absolute destination.
# Example:
#   conf/shared/etc/ssh/sshd_config  → /etc/ssh/sshd_config
#   conf/ubuntu/etc/bash.bashrc      → /etc/bash.bashrc

set -Eeuo pipefail
[[ -z "${_BOOTSTRAP_INIT_SOURCED:-}" ]] && echo "Must source init.sh first" >&2 && exit 1

# OS_ID must be set by the runner before sourcing this
_check_os_id() {
  if [[ -z "${OS_ID:-}" ]]; then
    _error "OS_ID not set (must be ubuntu or debian)"
    return 1
  fi
}

# ── Apply a single config file ────────────────────────────────────────────────
_apply_config_file() {
  local src="$1"
  local base_dir="$2"

  local rel="${src#$base_dir/}"
  local dest="/${rel}"

  # Safety: reject path escapes
  case "$dest" in
    /..*) _warn "Skipping unsafe path: $dest"; return ;;
  esac

  # Skip idempotency marker
  [[ "$dest" == "$MARKER_FILE" ]] && return

  _info "  $dest"
  _dry "Would render $src → $dest"
  _run render_to_file_mv "$src" "$dest"

  # Permissions by destination
  case "$dest" in
    /root/.bashrc|/root/.profile)   _run chmod 600 "$dest" ;;
    /etc/sudoers)                    _run chmod 440 "$dest" ;;
    /etc/shadow)                     _run chmod 600 "$dest" ;;
    /etc/ssh/sshd_config)            _run chmod 644 "$dest" ;;
    *)                               _run chmod 644 "$dest" ;;
  esac
}

# ── Main ───────────────────────────────────────────────────────────────────────
apply_os_configs() {
  _check_os_id || return 1

  local shared_dir="$BOOTSTRAP_CONF_DIR/shared"
  local os_conf_dir="$BOOTSTRAP_CONF_DIR/$OS_ID"

  # associative array: dest → src
  declare -A file_map

  # Shared (lower precedence)
  if [[ -d "$shared_dir" ]]; then
    _info "Applying shared configs from: $shared_dir/"
    while IFS= read -r src; do
      [[ -z "$src" ]] && continue
      local rel="${src#$shared_dir/}"
      local dest="/${rel}"
      file_map["$dest"]="$src"
    done < <(find "$shared_dir" -type f 2>/dev/null)
  fi

  # OS-specific (higher precedence — overrides shared)
  if [[ -d "$os_conf_dir" ]]; then
    _info "Applying OS configs from: $os_conf_dir/"
    while IFS= read -r src; do
      [[ -z "$src" ]] && continue
      local rel="${src#$os_conf_dir/}"
      local dest="/${rel}"
      file_map["$dest"]="$src"
    done < <(find "$os_conf_dir" -type f 2>/dev/null)
  fi

  # Apply all collected files
  for dest in "${!file_map[@]}"; do
    local src="${file_map[$dest]}"
    local base_dir
    if [[ -f "$shared_dir/${dest#/}" ]]; then
      base_dir="$shared_dir"
    else
      base_dir="$os_conf_dir"
    fi
    _apply_config_file "$src" "$base_dir"
  done

  # Validate and reload SSH
  if [[ -n "${file_map[/etc/ssh/sshd_config]:-}" ]]; then
    if sshd -t 2>/dev/null; then
      _info "sshd_config syntax OK"
      _run systemctl reload sshd 2>/dev/null || true
    else
      _warn "sshd_config has syntax errors, skipping reload"
    fi
  fi
}
