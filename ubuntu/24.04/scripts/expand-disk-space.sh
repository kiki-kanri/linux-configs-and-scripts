#!/bin/bash

growpart /dev/sda 3
pvresize
lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
xfs_growfs /
