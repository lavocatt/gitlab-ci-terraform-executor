#!/bin/bash
set -euxo pipefail
source /tmp/cloud_init_vars

# Set the system hostname.
hostnamectl set-hostname $SYSTEM_HOSTNAME
