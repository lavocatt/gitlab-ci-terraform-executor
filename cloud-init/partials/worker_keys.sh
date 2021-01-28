#!/bin/bash
set -euo pipefail
source /tmp/cloud_init_vars

echo "Deploy keys for workers."

# Deploy the composer CA certificate.
base64 -d - <<< ${OSBUILD_CA_CERT} > ${COMPOSER_DIR}/ca-crt.pem

# Deploy the composer key and certificate.
/usr/local/bin/aws secretsmanager get-secret-value \
  --endpoint-url ${SECRETS_MANAGER_ENDPOINT_URL} \
  --secret-id ${WORKER_SSL_KEYS_ARN} | jq -r ".SecretString" > /tmp/worker_keys.json
jq -r ".worker_key" /tmp/worker_keys.json | base64 -d - > ${COMPOSER_DIR}/worker-key.pem
jq -r ".worker_crt" /tmp/worker_keys.json | base64 -d - > ${COMPOSER_DIR}/worker-crt.pem
rm -f /tmp/worker_keys.json
