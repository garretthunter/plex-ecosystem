#!/bin/bash

REPO_URL="https://github.com/djdembeck/Audnexus.bundle.git"
TARGET_DIR="/config/Library/Application Support/Plex Media Server/Plug-ins/Audnexus.bundle"

git config --global --add safe.directory "${TARGET_DIR}"
# Check if the directory is empty
if [ -z "$(ls -A "${TARGET_DIR}" 2>/dev/null)" ]; then
    mkdir -p "${TARGET_DIR}"
    cd "${TARGET_DIR}"
    echo "Cloning repo ${REPO_URL} into `pwd`..."
    git clone ${REPO_URL} "${TARGET_DIR}"
else
    echo "Repository already exists, pulling most recent version."
    cd "${TARGET_DIR}"
    git pull
fi

exec /init
