#!/bin/bash
set -euo pipefail
source /tmp/cloud_init_vars

echo "Setting system hostname."

# Set the system hostname.
hostnamectl set-hostname $SYSTEM_HOSTNAME
