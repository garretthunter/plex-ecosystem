#!/bin/bash
PLUGIN_DIR="/config/Library/Application Support/Plex Media Server/Plug-ins/Audnexus.bundle"

if [ -d "${PLUGIN_DIR}/.git" ]; then
    git -C "${PLUGIN_DIR}" pull
else
    git clone https://github.com/djdembeck/Audnexus.bundle.git "${PLUGIN_DIR}"
fi
