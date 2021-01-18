#!/bin/bash
set -euo pipefail
source /tmp/cloud_init_vars

# Register the instance with RHN.
/usr/local/bin/aws secretsmanager get-secret-value \
  --secret-id ${SUBSCRIPTION_MANAGER_COMMAND_ARN} | jq -r ".SecretString" > /tmp/subscription_manager_command.json
jq -r ".subscription_manager_command" /tmp/subscription_manager_command.json | bash
rm -f /tmp/subscription_manager_command.json
