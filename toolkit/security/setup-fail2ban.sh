#!/usr/bin/env bash
# Install and auto-configure Fail2Ban protections for detected services.

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/libs/common.sh"

JAIL_DEST="/etc/fail2ban/jail.d/10-linux-configs-services.local"
BANTIME="24h"
FINDTIME="10m"
MAXRETRY="3"
IGNOREIP="127.0.0.1/8 ::1"

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

    [[ -n "${log_path}" ]] || return 0
    fail2ban_filter_exists "${jail_name}" || return 0

    append_jail "$(
        cat <<CONFIG
[${jail_name}]
enabled = true
port = ${port}
backend = auto
logpath = ${log_path}
CONFIG
    )"

    log_info "Enabled ${label} jail: ${log_path}"
}

add_nginx_jails() {
    local access_log=""
    local error_log=""

    [[ -d /var/log/nginx || -x /usr/sbin/nginx || -x /usr/local/nginx/sbin/nginx || -x /usr/local/sbin/nginx ]] || return 0

    access_log="$(first_existing_file /var/log/nginx/access.log /usr/local/nginx/logs/access.log 2>/dev/null || true)"
    error_log="$(first_existing_file /var/log/nginx/error.log /usr/local/nginx/logs/error.log 2>/dev/null || true)"

    add_log_jail nginx-http-auth http,https "${error_log}"
    add_log_jail nginx-botsearch http,https "${access_log}"
    add_log_jail nginx-bad-request http,https "${access_log}"
    add_log_jail nginx-limit-req http,https "${error_log}"
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

restart_fail2ban() {
    if command_exists fail2ban-client; then
        log_info "Checking generated Fail2Ban config..."
        fail2ban-client -t
    fi

    if command_exists systemctl; then
        log_info "Enabling and restarting fail2ban service..."
        systemctl enable fail2ban
        systemctl restart fail2ban
        return 0
    fi

    if command_exists service; then
        log_info "Restarting fail2ban service..."
        service fail2ban restart
        return 0
    fi

    log_warn "No supported service manager found; restart fail2ban manually."
}

show_status() {
    command_exists fail2ban-client || return 0

    log_info "Fail2Ban status:"
    fail2ban-client status || true
}

if (($# > 0)); then
    log_error "This script does not accept arguments; edit the script constants if policy changes are needed."
    exit 1
fi

require_root
require_cmd awk chmod grep install

apt_install_fail2ban
add_sshd_jail
add_nginx_jails
add_mail_jails
add_ftp_jails
add_recidive_jail
write_jail_config
restart_fail2ban
show_status

log_success "Fail2Ban protection is configured for detected services."
