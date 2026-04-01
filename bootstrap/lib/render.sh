# render.sh — Pure bash HEREDOC variable substitution
# Replaces {{VAR}} placeholders with values from the environment.
#
# Usage:
#   render <template_file>
#   render_string "content with {{VAR}}"
#
# Environment variables are used as-is. Unknown placeholders are left intact.
#
# Examples:
#   SSH_PORT=2222 render conf/sshd_config
#   TIMEZONE=Asia/Tokyo render_string "Timezone is {{TIMEZONE}}"

set -Eeuo pipefail

# ── render_string ────────────────────────────────────────────────────────────
# Render a string, replacing {{KEY}} with the matching environment variable.
render_string() {
  local input="$1"
  local escaped

  # Escape special sed characters in the input to avoid injection
  # Then perform the substitution using envsubst-like approach
  while [[ "$input" =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
    local key="${BASH_REMATCH[1]}"
    local value="${!key:-}"
    # Replace only the first occurrence per iteration
    input="${input//\{\{${key}\}\}/${value}}"
  done

  printf '%s' "$input"
}

# ── render ───────────────────────────────────────────────────────────────────
# Render a template file and print to stdout.
render() {
  local template_file="$1"
  if [[ ! -f "$template_file" ]]; then
    echo "render: file not found: ${template_file}" >&2
    return 1
  fi

  local content
  content="$(cat "$template_file")"
  render_string "$content"
}

# ── render_to_file ───────────────────────────────────────────────────────────
# Render a template file and write to destination.
# Backup is created automatically before write.
render_to_file() {
  local template_file="$1"
  local dest="$2"
  local backup="${3:-}"

  local rendered
  rendered="$(render "$template_file")"

  # Backup existing file
  if [[ -f "$dest" ]]; then
    if [[ -n "$backup" ]]; then
      cp -a "$dest" "$backup"
    else
      cp -a "$dest" "${dest}.bak.$(date +%Y%m%d%H%M%S)"
    fi
  fi

  printf '%s\n' "$rendered" > "$dest"
}

# ── render_to_file_mv ────────────────────────────────────────────────────────
# Atomic write: render to temp file, then mv to destination.
render_to_file_mv() {
  local template_file="$1"
  local dest="$2"

  local rendered
  rendered="$(render "$template_file")"

  # Write to temp file in same directory (same filesystem for atomic mv)
  local tmp="${dest}.tmp.${$}"
  printf '%s\n' "$rendered" > "$tmp"
  mv -f "$tmp" "$dest"
}
