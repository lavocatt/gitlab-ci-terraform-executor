#!/bin/bash
set -euo pipefail
source /tmp/cloud_init_vars

echo "Setting up worker services."

# Prepare osbuild-composer's remote worker services and sockets.
systemctl enable --now osbuild-remote-worker@${COMPOSER_HOST}:8700
