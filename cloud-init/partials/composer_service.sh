#!/bin/bash
set -euo pipefail
source /tmp/cloud_init_vars

echo "Setting up composer services."

# Adjust composer to listen on a non-standard port that is less likely to be
# scanned and probed.
# TODO(mhayden): We need access restrictions on the network level at some
# point, but we don't have it right now.
mkdir -p /etc/systemd/system/osbuild-composer-api.socket.d/
tee /etc/systemd/system/osbuild-composer-api.socket.d/override.conf > /dev/null << EOF
[Socket]
ListenStream=
ListenStream=9876
EOF
systemctl daemon-reload

# Prepare osbuild-composer's remote worker services and sockets.
systemctl mask osbuild-worker@1.service
systemctl enable --now osbuild-remote-worker.socket
systemctl enable --now osbuild-composer-api.socket

# Now that everything is configured, ensure monit is monitoring everything.
systemctl enable --now monit
