#!/bin/bash

# Set locale and timezone to zh_TW.UTF-8 and Asia/Taipei

# Install require app
sudo apt-get install locales tzdata

# Set timezone and locale
sudo ln -fs /usr/share/zoneinfo/Asia/Taipei /etc/localtime &&
    sudo dpkg-reconfigure -f noninteractive tzdata &&
    sudo locale-gen zh_TW.UTF-8 &&
    sudo update-locale LANG=zh_TW.UTF-8 &&
    sudo update-locale LANGUAGE=zh_TW.UTF-8 &&
    sudo update-locale LC_ALL=zh_TW.UTF-8
