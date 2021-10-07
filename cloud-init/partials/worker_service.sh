#!/bin/bash
set -euo pipefail
source /tmp/cloud_init_vars

echo "Setting up worker services."

# Prepare osbuild-composer's remote worker services and sockets.
systemctl enable --now osbuild-remote-worker@https:--${COMPOSER_HOST}:8700

# Now that everything is configured, ensure monit is monitoring everything.
systemctl enable --now monit
