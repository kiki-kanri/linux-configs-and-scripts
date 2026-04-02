# Linux Configs & Scripts Refactor Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan.

**Goal:** 重寫 `linux-configs-and-scripts` 專案，分為 `toolkit/`（隨選腳本）和 `bootstrap/`（新機完整設定）兩套，支援 Debian/Ubuntu × arm64/x86_64。

**Architecture:**
- **toolkit/** — 隨選執行腳本集，每個腳本獨立 idempotent，透過 `lib/` 共享 OS/架構偵測、日誌、錯誤處理。
- **bootstrap/** — 新機開箱腳本，偵測環境後複製設定、執行對應 toolkit 元件，分 `debian.sh` / `ubuntu.sh` 兩個 runner。
- **共享設計原則：** 所有腳本以 `lib/` 作為唯一共享 core，不複製程式碼；架構/OS 偵測統一在一處。

---

## 目錄結構

```
linux-configs-and-scripts/
├── README.md
├── LICENSE
│
├── lib/                        # ★ 兩套共享的 core library
│   ├── arch.sh                # 架構偵測 (x86_64/aarch64)
│   ├── os.sh                  # OS + 版本偵測 (debian/ubuntu + 版本)
│   ├── log.sh                 # 日誌函式 (info/warn/error/success)
│   ├── confirm.sh             # 確認提示 (yes/no prompt)
│   ├── require-root.sh        # 檢查 root 權限
│   ├── require-cmd.sh         # 檢查必要指令存在
│   ├── backup.sh              # 備份現有檔案再寫入
│   └── install-from-url.sh    # 下載並安裝 binary
│
├── toolkit/                    # ★ 區塊一：隨選工具腳本
│   ├── install/               # 安裝類
│   │   ├── acme.sh            # 安裝 acme.sh
│   │   ├── php.sh             # 安裝 PHP 8.x
│   │   ├── node.sh            # 安装 Node.js (nodesource)
│   │   ├── python.sh          # 安裝 Python 3.11+
│   │   ├── docker.sh          # 安裝 Docker + Docker Compose
│   │   ├── nginx.sh           # 安裝 Nginx (軟體包)
│   │   ├── mariadb.sh         # 安裝 MariaDB
│   │   ├── mongodb.sh         # 安裝 MongoDB Community
│   │   ├── redis.sh           # 安裝 Redis (Debian/Ubuntu)
│   │   └── nvidia.sh          # 安裝 NVIDIA driver + CUDA deps
│   ├── issue/                 # 憑證/金鑰類
│   │   ├── acme-issue.sh      # 透過 acme.sh 簽發 SSL 憑證
│   │   └── acme-renew.sh      # 自動更新 SSL 憑證
│   ├── maintenance/           # 維運類
│   │   ├── clear-logs.sh      # 清理 /var/log 下的舊日誌
│   │   ├── clear-docker-cache.sh  # 清理 Docker build cache
│   │   └── upgrade-packages.sh # 系統升級 (apt update && upgrade)
│   ├── service/              # 服務管理類
│   │   ├── nginx-service.sh   # 設定 Nginx systemd service
│   │   └── enable-thp.sh      # 啟用 Transparent Hugepage
│   └── init/                  # 一次性初始化類
│       ├── disable-ipv6.sh    # 停用 IPv6
│       ├── disable-motds.sh   # 停用 MOTD 登入訊息
│       ├── setup-locale.sh    # 設定系統 locale
│       └── setup-timezone.sh # 設定時區
│
├── bootstrap/                  # ★ 區塊二：新機完整設定
│   ├── lib/                   # bootstrap 專用 helpers (引用上層 lib/)
│   │   ├── check-env.sh      # 預檢查 (root, 網路, 必要工具)
│   │   └── main-menu.sh       # 互動式主選單
│   ├── conf/                  # 設定檔樣板 (依 OS 分發)
│   │   ├── os/
│   │   │   ├── debian/
│   │   │   │   ├── apt/sources.list.j2
│   │   │   │   └── sysctl/disable-ipv6.conf
│   │   │   └── ubuntu/
│   │   │       ├── apt/sources.list.j2
│   │   │       └── sysctl/disable-ipv6.conf
│   │   ├── shell/
│   │   │   ├── bash.bashrc.j2
│   │   │   ├── profile.j2
│   │   │   ├── skel/.bashrc.j2
│   │   │   └── root/.bashrc.j2
│   │   ├── ssh/
│   │   │   └── sshd_config.j2
│   │   ├── vim/
│   │   │   └── vimrc.j2
│   │   ├── nginx/
│   │   │   ├── nginx.conf.j2
│   │   │   ├── domains/
│   │   │   ├── locations/
│   │   │   ├── proxies/
│   │   │   └── ssls/
│   │   ├── cron.daily/
│   │   │   ├── clear-logs.j2
│   │   │   ├── clear-docker-cache.j2
│   │   │   └── upgrade-packages.j2
│   │   └── systemd/
│   │       └── nginx.service.j2
│   ├── scripts/               # bootstrap 專用 script
│   │   ├── install-base.sh    # 安裝 base packages
│   │   ├── apply-configs.sh   # 將 conf/* 同步到系統
│   │   ├── install-tools.sh    # 執行 toolkit 安裝腳本
│   │   └── configure-ssh.sh   # 設定 SSH (port, key only)
│   ├── runners/               # 依 OS 的 entry point
│   │   ├── debian.sh          # Debian bootstrap entry
│   │   └── ubuntu.sh          # Ubuntu bootstrap entry
│   └── setup.sh               # Bootstrap 通用 entry (偵測 OS 後分派)
│
└── tests/                      # 測試 (可選)
    ├── lib/
    ├── toolkit/
    └── bootstrap/
```

---

## lib/ 核心模組設計

### `lib/arch.sh`
```bash
# 回傳: x86_64 | aarch64
detect_architecture() {
    local arch
    arch=$(uname -m)
    case "${arch}" in
        x86_64)   echo "x86_64" ;;
        aarch64)  echo "aarch64" ;;
        arm64)    echo "aarch64" ;;
        *)        echo "unsupported" >&2; return 1 ;;
    esac
}

is_x86_64() { [ "$(detect_architecture)" = "x86_64" ]; }
is_aarch64() { [ "$(detect_architecture)" = "aarch64" ]; }
```

### `lib/os.sh`
```bash
# 回傳: debian-N | ubuntu-N (N 為版本號如 12, 22, 24)
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "${ID}" in
            debian)  echo "debian-${VERSION_ID}" ;;
            ubuntu)  echo "ubuntu-${VERSION_ID}" ;;
            *)       echo "unsupported" >&2; return 1 ;;
        esac
    fi
}

is_debian()  { [[ "$(detect_os)" == debian-* ]]; }
is_ubuntu()  { [[ "$(detect_os)" == ubuntu-* ]]; }
os_version() { detect_os | cut -d- -f2; }
```

### `lib/log.sh`
```bash
# 需要三個變數: SCRIPT_NAME (由呼叫者設定)
log_info()  { echo "[${SCRIPT_NAME}] INFO:  $*"; }
log_warn()  { echo "[${SCRIPT_NAME}] WARN:  $*" >&2; }
log_error() { echo "[${SCRIPT_NAME}] ERROR: $*" >&2; }
log_success(){ echo "[${SCRIPT_NAME}] SUCCESS: $*"; }

# 顏色版
log_info()  { echo -e "[\033[34m${SCRIPT_NAME}\033[0m] \033[34mINFO:\033[0m  $*"; }
# ... 其餘類似
```

---

## toolkit/ 腳本範本

每個腳本結構一致：

```bash
#!/bin/bash
# -*- mode: bash; tab-size: 4; -*-
set -euo pipefail

SCRIPT_NAME="$(basename "$0" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../lib"

# 載入 core lib
for lib in "${LIB_DIR}"/*.sh; do
    [[ -f "${lib}" ]] && source "${lib}"
done

# 靜默載入，避免重複 export
source "${LIB_DIR}/os.sh"      # 有需要才 load
source "${LIB_DIR}/arch.sh"    # 有需要才 load

main() {
    require_root
    # ... 主邏輯
}

main "$@"
```

---

## 實作順序

### Phase 1: Core Library (`lib/`)
1. 建立 `lib/arch.sh` — 架構偵測
2. 建立 `lib/os.sh` — OS/版本偵測
3. 建立 `lib/log.sh` — 日誌系統
4. 建立 `lib/confirm.sh` — yes/no 確認
5. 建立 `lib/require-root.sh` — root 檢查
6. 建立 `lib/require-cmd.sh` — 指令存在檢查
7. 建立 `lib/backup.sh` — 備份現有檔案
8. 建立 `lib/install-from-url.sh` — binary 下載安裝

### Phase 2: Toolkit — Install 類
9.  `toolkit/install/acme.sh`
10. `toolkit/install/php.sh`
11. `toolkit/install/node.sh`
12. `toolkit/install/python.sh`
13. `toolkit/install/docker.sh`
14. `toolkit/install/nginx.sh`
15. `toolkit/install/mariadb.sh`
16. `toolkit/install/mongodb.sh`
17. `toolkit/install/redis.sh`
18. `toolkit/install/nvidia.sh`

### Phase 3: Toolkit — Issue / Maintenance / Service / Init
19. `toolkit/issue/acme-issue.sh`
20. `toolkit/issue/acme-renew.sh`
21. `toolkit/maintenance/clear-logs.sh`
22. `toolkit/maintenance/clear-docker-cache.sh`
23. `toolkit/maintenance/upgrade-packages.sh`
24. `toolkit/service/nginx-service.sh`
25. `toolkit/service/enable-thp.sh`
26. `toolkit/init/disable-ipv6.sh`
27. `toolkit/init/disable-motds.sh`
28. `toolkit/init/setup-locale.sh`
29. `toolkit/init/setup-timezone.sh`

### Phase 4: Bootstrap — 設定檔
30. `bootstrap/conf/shell/`  各種 shell rc 樣板 (.j2)
31. `bootstrap/conf/ssh/sshd_config.j2`
32. `bootstrap/conf/vim/vimrc.j2`
33. `bootstrap/conf/os/debian/` + `ubuntu/` 設定檔
34. `bootstrap/conf/nginx/` 完整 Nginx 設定階層
35. `bootstrap/conf/cron.daily/` 三個 cron 樣板
36. `bootstrap/conf/systemd/nginx.service.j2`

### Phase 5: Bootstrap — 腳本
37. `bootstrap/lib/check-env.sh`
38. `bootstrap/lib/main-menu.sh`
39. `bootstrap/scripts/install-base.sh`
40. `bootstrap/scripts/apply-configs.sh`
41. `bootstrap/scripts/install-tools.sh`
42. `bootstrap/scripts/configure-ssh.sh`
43. `bootstrap/runners/debian.sh`
44. `bootstrap/runners/ubuntu.sh`
45. `bootstrap/setup.sh`

### Phase 6: 文件
46. 根目錄 `README.md`
47. `toolkit/README.md`
48. `bootstrap/README.md`

---

## 支援矩陣

| 腳本 | Debian 12 | Ubuntu 24.04 | arm64 | x86_64 |
|------|-----------|--------------|-------|--------|
| install/acme.sh | ✅ | ✅ | ✅ | ✅ |
| install/php.sh | ✅ | ✅ | ✅ | ✅ |
| install/node.sh | ✅ | ✅ | ✅ | ✅ |
| install/docker.sh | ✅ | ✅ | ✅ | ✅ |
| install/nginx.sh | ✅ | ✅ | ✅ | ✅ |
| install/mariadb.sh | ✅ | ✅ | ✅ | ✅ |
| install/mongodb.sh | ✅ | ✅ | ✅ | ✅ |
| install/redis.sh | ✅ | ✅ | ✅ | ✅ |
| install/nvidia.sh | N/A | ✅ | ✅ | ✅ |
| bootstrap/setup.sh | ✅ | ✅ | ✅ | ✅ |

---

## Idempotency 原則

每個 `toolkit/install/*.sh` 必須：
1. 開頭檢查「是否已安裝」並禮貌退出 `log_info "Already installed, skipping."`
2. 使用 `apt-get install -y --no-install-recommends` 避免雜亂
3. 不假設網路一定通，必要時 `require-cmd curl`

---

## 驗證方式

```bash
# 測試 lib 載入順序
bash -n toolkit/install/nginx.sh       # syntax check
shellcheck toolkit/install/*.sh         # static analysis (if installed)

# 測試 OS 偵測
source lib/os.sh && detect_os            # 確認輸出正確

# 測試 bootstrap runner (dry-run mode)
SKIP_APPLY=1 ./bootstrap/runners/ubuntu.sh --dry-run
```
