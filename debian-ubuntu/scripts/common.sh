#!/bin/bash

if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "${ID}" = 'debian' ]; then
        export os_type='debian'
    elif [ "${ID}" = 'ubuntu' ]; then
        export os_type='ubuntu'
    else
        echo "Unsupported OS: ${ID}. Exiting script."
        exit 1
    fi

    export os_version_id=${VERSION_ID}
else
    echo '/etc/os-release file not found. Exiting script.'
    exit 1
fi
