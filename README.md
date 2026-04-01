# linux-configs-and-scripts

# Run bootstrap for ubuntu 24.04

```bash
sudo apt-get update && \
    sudo apt-get install -y curl git && \
    curl -fsSL https://raw.githubusercontent.com/kiki-kanri/linux-configs-and-scripts/refs/heads/main/bootstrap/ubuntu/setup.sh | sudo bash -
```
