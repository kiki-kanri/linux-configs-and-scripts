#!/bin/bash

set -euo pipefail

GLIBC_TUNABLES='glibc.pthread.rseq=0' \
    LD_PRELOAD='/opt/mongodb/libforce_enable_thp.so' \
    exec mongod --bind_ip_all --replSet rs0 "$@"
