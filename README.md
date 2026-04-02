# linux-configs-and-scripts

# Run bootstrap for ubuntu 24.04

```bash
sudo apt-get update && \
    sudo apt-get install -y curl && \
    curl \
        -fsSL \
        -H 'Cache-Control: no-cache, no-store, must-revalidate' \
        -H 'Expires: 0' \
        -H 'Pragma: no-cache' \
        "https://raw.githubusercontent.com/kiki-kanri/linux-configs-and-scripts/refs/heads/main/bootstrap/ubuntu/setup.sh?t=$(openssl rand -hex 8)" \
        | sudo bash -
```
