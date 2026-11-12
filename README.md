# linux-configs-and-scripts

## Run bootstrap for Ubuntu 24.04 / 26.04 / 26.10

```bash
sudo bash -c "$(
    cat <<'BOOTSTRAP'
set -euo pipefail

main() (
    local work_dir

    apt-get update
    apt-get install -y ca-certificates curl

    work_dir="$(mktemp -d /tmp/linux-configs-and-scripts-bootstrap.XXXXXX)"
    trap 'rm -rf -- "${work_dir}"' EXIT

    curl \
        -fsSL \
        -H 'Cache-Control: no-cache, no-store, must-revalidate' \
        -H 'Expires: 0' \
        -H 'Pragma: no-cache' \
        -o "${work_dir}/run.sh" \
        "https://raw.githubusercontent.com/kiki-kanri/linux-configs-and-scripts/refs/heads/main/bootstrap/ubuntu/setup/run.sh?t=$(date +%s%N)"

    bash "${work_dir}/run.sh"
)

main "$@"
BOOTSTRAP
)"
```

## Nginx: restrict selected sites to Cloudflare

For both new installations and hosts already installed with `build-nginx.sh`, run `sudo toolkit/service/setup-cloudflare-nginx.sh` to install or refresh the updater; there is no need to rebuild nginx. New `build-nginx.sh` runs the setup automatically. The updater installs `/etc/nginx/conf.d/cloudflare-nginx.conf`, which maintains both the trusted real-IP ranges and a `$from_cloudflare` check against the original TCP peer. The same verified Cloudflare IPv4/IPv6 lists feed both rules and are refreshed together by `cloudflare-nginx-update.timer`. Setup replaces the old real-IP updater, timer, and generated configuration.

For each site that must not be reached directly through the origin IP, add this **inside its `server {}` block**, before any unconditional `return`:

```nginx
include public/access/cloudflare-only.conf;
```

The included rule returns 444 for non-Cloudflare peers. Other sites remain unchanged. Add it to every relevant HTTP and HTTPS server block, including alternate hostnames/listeners; otherwise those paths can still be reached directly. Do not use `$remote_addr` for this check: real-IP processing changes it to the visitor address. Do not trust `0.0.0.0/0` or `::/0` with `set_real_ip_from`.

This is per-site HTTP access control, **not** a network firewall or proof that a request belongs to your Cloudflare zone. TCP/TLS traffic still reaches the origin, and another Cloudflare customer may be able to send traffic from a trusted Cloudflare IP. Use a firewall for network-level protection and, where appropriate, Authenticated Origin Pulls for stronger HTTPS origin authentication.
