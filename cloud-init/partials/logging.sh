#!/bin/bash
set -euo pipefail
source /tmp/cloud_init_vars

echo "Setting up logging."

tee /etc/vector/vector.toml > /dev/null << EOF
[sources.journald]
type = "journald"
exclude_units = ["vector.service"]

[sinks.out]
type = "aws_cloudwatch_logs"
inputs = [ "journald" ]
endpoint = "${CLOUDWATCH_LOGS_ENDPOINT_URL}"
group_name = "internal_composer_staging"
stream_name = "internal_composer_syslog"
encoding.codec = "json"
EOF

systemctl enable --now vector
