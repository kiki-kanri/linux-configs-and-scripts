#!/usr/bin/env bash
# Install and auto-configure Fail2Ban protections for detected services.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

JAIL_DEST="/etc/fail2ban/jail.d/10-linux-configs-services.local"
FAIL2BAN_LOCAL_DEST="/etc/fail2ban/fail2ban.local"
NGINX_DENY_ACTION_DEST="/etc/fail2ban/action.d/nginx-deny.conf"
NGINX_DENY_CONF="/etc/nginx/conf.d/fail2ban-deny.conf"
BANTIME="24h"
FINDTIME="10m"
MAXRETRY="3"
IGNOREIP="127.0.0.1/8 ::1"
NGINX_DENY_HEADER="# Managed by fail2ban nginx-deny action.
# Banned IPs are appended below as nginx access-module deny directives."

nginx_bin_candidates=(
    /usr/sbin/nginx
    /usr/local/sbin/nginx
    /usr/local/nginx/sbin/nginx
)

jail_blocks=()

append_jail() {
    jail_blocks+=("$1")
}

apt_install_fail2ban() {
    require_cmd apt-get

    log_info "Updating package index..."
    apt-get update

    log_info "Installing Fail2Ban packages..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        fail2ban \
        python3-pyinotify \
        python3-systemd \
        whois
}

fail2ban_filter_exists() {
    local filter_name="$1"
    [[ -f "/etc/fail2ban/filter.d/${filter_name}.conf" || -f "/etc/fail2ban/filter.d/${filter_name}.local" ]]
}

ufw_is_active() {
    command_exists ufw || return 1
    ufw status 2>/dev/null | grep -qi '^Status:[[:space:]]*active'
}

select_banaction_line() {
    if ufw_is_active; then
        printf 'banaction = ufw\n'
    fi
}

detect_sshd_port() {
    local config_file="/etc/ssh/sshd_config"
    local detected=""

    if [[ -x /usr/sbin/sshd ]]; then
        detected="$(/usr/sbin/sshd -T 2>/dev/null | awk '$1 == "port" && $2 ~ /^[0-9]+$/ && !seen[$2]++ { ports = ports ? ports "," $2 : $2 } END { print ports }')"
    fi

    if [[ -z "${detected}" && -r "${config_file}" ]]; then
        detected="$(awk 'tolower($1) == "port" && $2 ~ /^[0-9]+$/ && !seen[$2]++ { ports = ports ? ports "," $2 : $2 } END { print ports }' "${config_file}")"
    fi

    if [[ -n "${detected}" ]]; then
        printf '%s\n' "${detected}"
        return 0
    fi

    printf 'ssh\n'
}

add_sshd_jail() {
    local port
    port="$(detect_sshd_port)"

    append_jail "$(
        cat <<CONFIG
[sshd]
enabled = true
port = ${port}
backend = systemd
mode = aggressive
CONFIG
    )"

    log_info "Enabled sshd jail on port: ${port}"
}

first_existing_file() {
    local path
    for path in "$@"; do
        [[ -f "${path}" ]] || continue
        printf '%s\n' "${path}"
        return 0
    done

    return 1
}

add_log_jail() {
    local jail_name="$1"
    local port="$2"
    local log_path="$3"
    local label="${4:-${jail_name}}"
    local action="${5:-}"
    local action_line=""

    [[ -n "${log_path}" ]] || return 0
    fail2ban_filter_exists "${jail_name}" || return 0
    [[ -z "${action}" ]] || action_line=$'\n'"${action}"

    append_jail "$(
        cat <<CONFIG
[${jail_name}]
enabled = true
port = ${port}
backend = auto
logpath = ${log_path}${action_line}
CONFIG
    )"

    log_info "Enabled ${label} jail: ${log_path}"
}

nginx_command() {
    local candidate

    if command_exists nginx; then
        command -v nginx
        return 0
    fi

    for candidate in "${nginx_bin_candidates[@]}"; do
        [[ -x "${candidate}" ]] || continue
        printf '%s\n' "${candidate}"
        return 0
    done

    return 1
}

add_nginx_jails() {
    local access_log=""
    local error_log=""

    nginx_command >/dev/null || return 0

    access_log="$(first_existing_file /var/log/nginx/access.log /usr/local/nginx/logs/access.log 2>/dev/null || true)"
    error_log="$(first_existing_file /var/log/nginx/error.log /usr/local/nginx/logs/error.log 2>/dev/null || true)"

    add_log_jail nginx-http-auth http,https "${error_log}" nginx-http-auth "action = nginx-deny[blockfile=${NGINX_DENY_CONF}]"
    add_log_jail nginx-botsearch http,https "${access_log}" nginx-botsearch "action = nginx-deny[blockfile=${NGINX_DENY_CONF}]"
}

postfix_detected() {
    [[ -x /usr/sbin/postfix || -d /etc/postfix ]]
}

dovecot_detected() {
    [[ -x /usr/sbin/dovecot || -d /etc/dovecot ]]
}

add_mail_jails() {
    local mail_log=""

    mail_log="$(first_existing_file /var/log/mail.log /var/log/maillog 2>/dev/null || true)"
    [[ -n "${mail_log}" ]] || return 0

    if postfix_detected; then
        add_log_jail postfix smtp,465,submission "${mail_log}"
        add_log_jail postfix-sasl smtp,465,submission "${mail_log}"
    fi

    if dovecot_detected; then
        add_log_jail dovecot imap,imaps,pop3,pop3s "${mail_log}"
    fi
}

add_ftp_jails() {
    local auth_log=""
    local vsftpd_log=""
    local pureftpd_log=""

    auth_log="$(first_existing_file /var/log/auth.log /var/log/secure 2>/dev/null || true)"

    if [[ -x /usr/sbin/vsftpd || -f /etc/vsftpd.conf || -f /var/log/vsftpd.log ]]; then
        vsftpd_log="$(first_existing_file /var/log/vsftpd.log 2>/dev/null || true)"
        add_log_jail vsftpd ftp,ftp-data,ftps,ftps-data "${vsftpd_log:-${auth_log}}"
    fi

    if [[ -x /usr/sbin/pure-ftpd || -d /etc/pure-ftpd || -f /var/log/pure-ftpd/pure-ftpd.log ]]; then
        pureftpd_log="$(first_existing_file /var/log/pure-ftpd/pure-ftpd.log /var/log/syslog 2>/dev/null || true)"
        add_log_jail pure-ftpd ftp,ftp-data,ftps,ftps-data "${pureftpd_log}"
    fi
}

add_recidive_jail() {
    local fail2ban_log="/var/log/fail2ban.log"

    fail2ban_filter_exists recidive || return 0
    [[ -f "${fail2ban_log}" ]] || install -m 640 /dev/null "${fail2ban_log}"
    chmod 640 "${fail2ban_log}"

    append_jail "$(
        cat <<CONFIG
[recidive]
enabled = true
backend = auto
logpath = ${fail2ban_log}
bantime = 7d
findtime = 1d
maxretry = 3
CONFIG
    )"

    log_info "Enabled recidive jail for repeat offenders."
}

write_nginx_deny_header() {
    printf '%s\n' "${NGINX_DENY_HEADER}" >"${NGINX_DENY_CONF}"
    chmod 644 "${NGINX_DENY_CONF}"
}

install_nginx_deny_action() {
    local deny_dir
    local nginx_bin

    nginx_bin="$(nginx_command)" || return 0
    deny_dir="$(dirname -- "${NGINX_DENY_CONF}")"
    install -d -m 755 "$(dirname -- "${NGINX_DENY_ACTION_DEST}")" "${deny_dir}"

    log_info "Installing nginx deny Fail2Ban action: ${NGINX_DENY_ACTION_DEST}"
    cat >"${NGINX_DENY_ACTION_DEST}" <<'CONFIG'
# Managed by linux-configs-and-scripts/toolkit/security/setup-fail2ban.sh

[Definition]
actionstart = /bin/sh -c 'install -d -m 755 "$(dirname -- "<blockfile>")"; touch "<blockfile>"; chmod 644 "<blockfile>"; <nginxcmd> -t'
actionstop = /bin/true
actioncheck = test -f <blockfile>
actionban = /bin/sh -c 'line="deny <ip>;"; grep -qxF "$line" "<blockfile>" || echo "$line" >> "<blockfile>"; <nginxcmd> -t && <nginxcmd> -s reload'
actionunban = /bin/sh -c 'if [ -f "<blockfile>" ]; then sed -i "\#^deny <ip>;\$#d" "<blockfile>"; <nginxcmd> -t && <nginxcmd> -s reload; fi'

[Init]
blockfile = /etc/nginx/conf.d/fail2ban-deny.conf
CONFIG
    printf 'nginxcmd = %s\n' "${nginx_bin}" >>"${NGINX_DENY_ACTION_DEST}"
    chmod 644 "${NGINX_DENY_ACTION_DEST}"

    [[ -f "${NGINX_DENY_CONF}" ]] || write_nginx_deny_header
}

reset_nginx_deny_state() {
    local deny_dir
    local nginx_bin

    nginx_bin="$(nginx_command)" || return 0
    deny_dir="$(dirname -- "${NGINX_DENY_CONF}")"
    install -d -m 755 "${deny_dir}"

    log_info "Resetting nginx Fail2Ban deny state: ${NGINX_DENY_CONF}"
    write_nginx_deny_header

    if "${nginx_bin}" -t >/dev/null 2>&1; then
        "${nginx_bin}" -s reload >/dev/null 2>&1 || log_warn "Could not reload nginx after resetting Fail2Ban deny state."
    else
        log_warn "nginx config test failed after resetting Fail2Ban deny state; nginx was not reloaded."
    fi
}

write_fail2ban_daemon_config() {
    local end_marker="# END linux-configs-and-scripts"
    local start_marker="# BEGIN linux-configs-and-scripts"
    local tmp

    tmp="$(mktemp)"
    if [[ -f "${FAIL2BAN_LOCAL_DEST}" ]]; then
        awk -v start="${start_marker}" -v end="${end_marker}" '
            $0 == start { skip = 1; next }
            $0 == end { skip = 0; next }
            !skip { print }
        ' "${FAIL2BAN_LOCAL_DEST}" >"${tmp}"
    fi

    {
        cat "${tmp}"
        cat <<CONFIG
${start_marker}
[Definition]
allowipv6 = auto
${end_marker}
CONFIG
    } >"${FAIL2BAN_LOCAL_DEST}"

    rm -f "${tmp}"
    chmod 644 "${FAIL2BAN_LOCAL_DEST}"
}

write_jail_config() {
    local banaction_line
    banaction_line="$(select_banaction_line)"

    log_info "Writing Fail2Ban jail config: ${JAIL_DEST}"
    install -d -m 755 "$(dirname -- "${JAIL_DEST}")"

    {
        cat <<CONFIG
# Managed by linux-configs-and-scripts/toolkit/security/setup-fail2ban.sh
# Auto-generated from detected local services. Re-run the script after service/log changes.

[DEFAULT]
ignoreip = ${IGNOREIP}
bantime = ${BANTIME}
findtime = ${FINDTIME}
maxretry = ${MAXRETRY}
usedns = no
bantime.increment = true
bantime.factor = 2
bantime.maxtime = 7d
${banaction_line}
CONFIG
        printf '\n%s\n' "${jail_blocks[@]}"
    } >"${JAIL_DEST}"

    chmod 644 "${JAIL_DEST}"
}

wait_for_fail2ban() {
    local attempt

    command_exists fail2ban-client || return 0

    for ((attempt = 1; attempt <= 10; attempt += 1)); do
        if fail2ban-client ping >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    log_error "Fail2Ban did not become ready after restart."
    if command_exists systemctl; then
        systemctl --no-pager --full status fail2ban >&2 || true
    fi
    return 1
}

restart_fail2ban() {
    if command_exists fail2ban-client; then
        log_info "Checking generated Fail2Ban config..."
        fail2ban-client -t
    fi

    if command_exists systemctl; then
        log_info "Enabling and restarting fail2ban service..."
        systemctl enable fail2ban
        systemctl restart fail2ban
        wait_for_fail2ban
        return 0
    fi

    if command_exists service; then
        log_info "Restarting fail2ban service..."
        service fail2ban restart
        wait_for_fail2ban
        return 0
    fi

    log_warn "No supported service manager found; restart fail2ban manually."
}

show_status() {
    command_exists fail2ban-client || return 0

    log_info "Fail2Ban status:"
    fail2ban-client status || log_warn "Could not read Fail2Ban status."
}

if (($# > 0)); then
    log_error "This script does not accept arguments; edit the script constants if policy changes are needed."
    exit 1
fi

require_root
require_cmd awk cat chmod grep install mktemp rm dirname

apt_install_fail2ban
add_sshd_jail
add_nginx_jails
add_mail_jails
add_ftp_jails
add_recidive_jail
install_nginx_deny_action
reset_nginx_deny_state
write_fail2ban_daemon_config
write_jail_config
restart_fail2ban
show_status

log_success "Fail2Ban protection is configured for detected services."
