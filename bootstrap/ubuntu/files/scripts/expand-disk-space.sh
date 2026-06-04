#!/usr/bin/env bash
# Grow the root partition, LVM volume and filesystem when supported.

set -euo pipefail

ROOT_MOUNT="/"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

first_lvm_pv_for_root() {
    local vg_name

    command_exists lvs || return 1
    command_exists pvs || return 1

    vg_name="$(lvs --noheadings -o vg_name "${root_source}" 2>/dev/null | awk 'NF { print $1; exit }')"
    [[ -n "${vg_name}" ]] || return 1

    pvs --noheadings -o pv_name --select "vg_name=${vg_name}" 2>/dev/null | awk 'NF { print $1; exit }'
}

detect_partition_and_disk() {
    local source="$1"
    local pkname kname

    kname="$(lsblk -no KNAME "${source}" 2>/dev/null | awk 'NF { print $1; exit }')"
    pkname="$(lsblk -no PKNAME "${source}" 2>/dev/null | awk 'NF { print $1; exit }')"
    [[ -n "${kname}" && -n "${pkname}" ]] || return 1

    root_partition="/dev/${kname}"
    root_disk="/dev/${pkname}"
    root_part_number="${root_partition##*[!0-9]}"
    [[ -n "${root_part_number}" ]]
}

grow_root_partition() {
    command_exists growpart || return 0
    [[ -n "${root_disk}" && -n "${root_part_number}" ]] || return 0

    growpart "${root_disk}" "${root_part_number}" || true
}

grow_lvm_if_needed() {
    [[ -n "${root_pv}" ]] || return 0
    command_exists pvresize || return 0
    command_exists lvextend || return 0

    pvresize "${root_pv}" || true
    lvextend -l +100%FREE "${root_source}" || true
}

grow_root_filesystem() {
    case "${root_fstype}" in
    ext2 | ext3 | ext4)
        command_exists resize2fs || {
            printf 'resize2fs is required for %s root filesystem\n' "${root_fstype}" >&2
            exit 1
        }
        resize2fs "${root_source}"
        ;;
    xfs)
        command_exists xfs_growfs || {
            printf 'xfs_growfs is required for xfs root filesystem\n' >&2
            exit 1
        }

        xfs_growfs "${ROOT_MOUNT}"
        ;;
    *)
        printf 'Unsupported root filesystem for online resize: %s\n' "${root_fstype}" >&2
        exit 1
        ;;
    esac
}

root_source="$(findmnt -no SOURCE --target "${ROOT_MOUNT}")"
root_fstype="$(findmnt -no FSTYPE --target "${ROOT_MOUNT}")"
root_pv="$(first_lvm_pv_for_root || true)"
root_partition=""
root_disk=""
root_part_number=""

if [[ -n "${root_pv}" ]]; then
    detect_partition_and_disk "${root_pv}" || true
else
    detect_partition_and_disk "${root_source}" || true
fi

grow_root_partition
grow_lvm_if_needed
grow_root_filesystem
