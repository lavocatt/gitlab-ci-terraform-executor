#!/bin/bash
set -euo pipefail
source /tmp/cloud_init_vars

echo "Deploy cloud credentials for workers."

# Deploy the GCP Service Account credentials file.
/usr/local/bin/aws secretsmanager get-secret-value \
  --endpoint-url ${SECRETS_MANAGER_ENDPOINT_URL} \
  --secret-id ${GCP_SERVICE_ACCOUNT_IMAGE_BUILDER_ARN} | jq -r ".SecretString" > ${WORKER_DIR}/gcp_credentials.json

# Deploy the Azure credentials file.
/usr/local/bin/aws secretsmanager get-secret-value \
  --endpoint-url ${SECRETS_MANAGER_ENDPOINT_URL} \
  --secret-id ${GCP_SERVICE_ACCOUNT_IMAGE_BUILDER_ARN} | jq -r ".SecretString" > /tmp/azure_credentials.json
CLIENT_ID=$(jq -r ".client_id" /tmp/azure_credentials)
CLIENT_SECRET=$(jq -r ".client_secret" /tmp/azure_credentials)
rm /tmp/azure_credentials.json

sudo tee /etc/osbuild-worker/azure_credentials.toml > /dev/null << EOF
client_id =     "$CLIENT_ID"
client_secret = "$CLIENT_SECRET"
EOF
