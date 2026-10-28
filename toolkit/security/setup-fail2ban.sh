#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../../libs/common.sh"

# Constants/Variables
readonly FAIL2BAN_CONF_DIR="${REPO_ROOT}/toolkit/conf/fail2ban"
readonly JAIL_DEST='/etc/fail2ban/jail.d/10-linux-configs-services.local'

# Functions
first_existing_file() {
    local path

    for path in "$@"; do
        if [[ -f "${path}" ]]; then
            printf '%s\n' "${path}"
            return 0
        fi
    done

    # No matching log is normal on journal-only installations.
    printf '\n'
}

write_jail() {
    local name="$1" port="$2" backend="$3" log_path="${4:-}"

    printf '\n[%s]\nenabled = true\nport = %s\nbackend = %s\n' "${name}" "${port}" "${backend}"
    if [[ -n "${log_path}" ]]; then
        printf 'logpath = %s\n' "${log_path}"
    fi

    log_info "Enabling Fail2Ban jail: ${name}" >&2
}

write_sshd_jail() {
    local ports

    if [[ ! -x /usr/sbin/sshd ]]; then
        # Debian's package enables this jail even when OpenSSH is absent.
        printf '\n[sshd]\nenabled = false\n'
        return 0
    fi

    # Read the effective config, including Include directives and multiple ports.
    ports="$(/usr/sbin/sshd -T | awk '$1 == "port" && !seen[$2]++ { ports = ports ? ports "," $2 : $2 } END { print ports }')"
    if [[ -z "${ports}" ]]; then
        log_error 'No SSH port found in the effective sshd configuration'
        return 1
    fi

    write_jail sshd "${ports}" systemd
    printf 'mode = aggressive\n'
}

write_nginx_jails() {
    local name log_path blockfile nginx_config
    local -a enabled_jails=()

    if [[ ! -x /usr/sbin/nginx ]]; then
        return 0
    fi

    install -d -m 755 /etc/nginx/conf.d
    for name in nginx-http-auth nginx-botsearch; do
        case "${name}" in
        nginx-http-auth) log_path='/var/log/nginx/error.log' ;;
        nginx-botsearch) log_path='/var/log/nginx/access.log' ;;
        esac

        if [[ ! -f "${log_path}" ]]; then
            log_warn "No matching log file; skipping jail: ${name}"
            continue
        fi

        blockfile="/etc/nginx/conf.d/fail2ban-${name}.conf"
        touch "${blockfile}"
        chown root:root "${blockfile}"
        chmod 644 "${blockfile}"
        enabled_jails+=("${name}")

        write_jail "${name}" http,https auto "${log_path}"
        printf 'ignoreip = %%(nginx_ignoreip)s\naction = nginx-deny[name=%s]\n' "${name}"
    done

    if ((${#enabled_jails[@]} > 0)); then
        nginx_config="$(/usr/sbin/nginx -T 2>&1)" || {
            log_error "Nginx configuration test failed: ${nginx_config}"
            return 1
        }

        for name in "${enabled_jails[@]}"; do
            if ! grep -qF "# configuration file /etc/nginx/conf.d/fail2ban-${name}.conf:" <<<"${nginx_config}"; then
                log_error "Nginx must include /etc/nginx/conf.d/*.conf; jail would be ineffective: ${name}"
                return 1
            fi
        done
    fi
}

write_mail_jails() {
    local mail_log backend name

    mail_log="$(first_existing_file /var/log/mail.log /var/log/maillog)"
    backend='systemd'
    if [[ -n "${mail_log}" ]]; then
        backend='auto'
    fi

    if [[ -x /usr/sbin/postfix || -d /etc/postfix ]]; then
        for name in postfix postfix-sasl; do
            write_jail "${name}" smtp,465,submission "${backend}" "${mail_log}"
            if [[ "${name}" == 'postfix-sasl' ]]; then
                # Upstream uses the postfix filter's auth mode, not postfix-sasl.conf.
                printf 'filter = postfix[mode=auth]\n'
            fi

            if [[ "${backend}" == 'systemd' ]]; then
                printf 'journalmatch = _SYSTEMD_UNIT=postfix.service _SYSTEMD_UNIT=postfix@-.service\n'
            fi
        done
    fi

    if [[ -x /usr/sbin/dovecot || -d /etc/dovecot ]]; then
        write_jail dovecot imap,imaps,pop3,pop3s "${backend}" "${mail_log}"
    fi
}

write_ftp_jails() {
    local log_path

    if [[ -x /usr/sbin/vsftpd || -f /etc/vsftpd.conf ]]; then
        log_path="$(first_existing_file /var/log/vsftpd.log /var/log/auth.log /var/log/secure)"
        if [[ -n "${log_path}" ]]; then
            write_jail vsftpd ftp,ftp-data,ftps,ftps-data auto "${log_path}"
        else
            write_jail vsftpd ftp,ftp-data,ftps,ftps-data systemd
            printf 'journalmatch = _SYSTEMD_UNIT=vsftpd.service + _COMM=vsftpd\n'
        fi
    fi

    if [[ -x /usr/sbin/pure-ftpd || -d /etc/pure-ftpd ]]; then
        # Pure-FTPd's transfer log is not an authentication failure log.
        log_path="$(first_existing_file /var/log/syslog /var/log/auth.log /var/log/messages)"
        if [[ -n "${log_path}" ]]; then
            write_jail pure-ftpd ftp,ftp-data,ftps,ftps-data auto "${log_path}"
        else
            write_jail pure-ftpd ftp,ftp-data,ftps,ftps-data systemd
        fi
    fi
}

wait_for_fail2ban() {
    local attempt

    # The packaged unit is Type=simple: systemctl returns before the socket is ready.
    for ((attempt = 0; attempt < 15; attempt++)); do
        if fail2ban-client ping >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    log_error 'Fail2Ban did not become ready within 15 seconds; inspect journalctl -u fail2ban'
    return 1
}

# Run
main() (
    local ID VERSION_ID PRETTY_NAME

    require_root
    source /etc/os-release
    case "${ID}:${VERSION_ID}" in
    debian:12 | debian:13 | ubuntu:24.04 | ubuntu:26.04) ;;
    *)
        log_error "Unsupported operating system release: ${PRETTY_NAME}"
        exit 1
        ;;
    esac

    require_cmd apt-get systemctl

    log_info 'Updating package index...'
    apt-get update
    log_info 'Installing Fail2Ban packages...'
    apt-get install -y --no-install-recommends fail2ban nftables python3-pyinotify python3-systemd

    log_info 'Installing Fail2Ban configuration...'
    install -D -o root -g root -m 644 "${FAIL2BAN_CONF_DIR}/fail2ban.d/10-linux-configs.local" /etc/fail2ban/fail2ban.d/10-linux-configs.local
    install -D -o root -g root -m 644 "${FAIL2BAN_CONF_DIR}/action.d/nginx-deny.conf" /etc/fail2ban/action.d/nginx-deny.conf
    install -D -o root -g root -m 644 "${FAIL2BAN_CONF_DIR}/jail.d/10-linux-configs-services.local" "${JAIL_DEST}"
    install -D -o root -g root -m 644 "${REPO_ROOT}/toolkit/conf/systemd/fail2ban.service.d/10-nginx-ordering.conf" /etc/systemd/system/fail2ban.service.d/10-nginx-ordering.conf
    touch /var/log/fail2ban.log
    chmod 640 /var/log/fail2ban.log

    {
        write_sshd_jail
        write_nginx_jails
        write_mail_jails
        write_ftp_jails
    } >>"${JAIL_DEST}"

    log_info 'Validating Fail2Ban configuration...'
    fail2ban-client -t

    log_info 'Enabling and restarting Fail2Ban...'
    systemctl daemon-reload
    systemctl enable fail2ban
    systemctl restart fail2ban
    wait_for_fail2ban
    fail2ban-client status

    log_success 'Fail2Ban protection configured for detected services'
)

main "$@"
