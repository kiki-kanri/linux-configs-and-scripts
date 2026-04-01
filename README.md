# linux-configs-and-scripts

# Run bootstrap

```bash
sudo apt-get update && \
    sudo apt-get install -y curl git && \
    cd /tmp && \
    rm -rf ./linux-configs-and-scripts/ && \
    git clone https://github.com/kiki-kanri/linux-configs-and-scripts.git && \
    cd ./linux-configs-and-scripts/ && \
    bash ./bootstrap/setup.sh
```
