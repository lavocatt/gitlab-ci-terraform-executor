#!/bin/bash
set -euo pipefail
source /tmp/cloud_init_vars

echo "Deploy /etc/hosts for workers."

# Set up /etc/hosts
# TODO(mhayden): We need to convert this to DNS later when we launch.
cat <<< "${COMPOSER_ADDRESS} ${COMPOSER_HOST}" >> /etc/hosts
