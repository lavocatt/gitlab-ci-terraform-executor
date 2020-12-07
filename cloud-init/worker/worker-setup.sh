# Forward systemd journal to the console for easier viewing.
# This is done at the beginning of this script so we log all errors.
mkdir -p /etc/systemd/journald.conf.d/
tee /etc/systemd/journald.conf.d/forward-to-console.conf > /dev/null << EOF
[Journal]
ForwardToConsole=yes
MaxLevelConsole=6
EOF

# Ensure the SELinux contexts are correct.
restorecon -Rv /etc/systemd

# Restart journald to pick up the console log change.
systemctl restart systemd-journald

# Variables for the script.
COMPOSER_DIR=/etc/osbuild-composer

# Set up /etc/hosts
# TODO(mhayden): We need to convert this to DNS later when we launch.
cat <<< "${COMPOSER_ADDRESS} ${COMPOESR_HOST}" >> /etc/hosts

# Deploy the composer CA certificate.
mkdir ${COMPOSER_DIR}
base64 -d - <<< ${OSBUILD_CA_CERT} > ${COMPOSER_DIR}/ca-crt.pem

# Deploy the composer key and certificate.
/usr/local/bin/aws secretsmanager get-secret-value \
  --secret-id ${WORKER_SSL_KEYS_ARN} | jq -r ".SecretString" > /tmp/worker_keys.json
jq -r ".worker_key" /tmp/worker_keys.json | base64 -d - > ${COMPOSER_DIR}/worker-key.pem
jq -r ".worker_crt" /tmp/worker_keys.json | base64 -d - > ${COMPOSER_DIR}/worker-crt.pem
rm -f /tmp/worker_keys.json

# Prepare osbuild-composer's remote worker services and sockets.
systemctl enable --now osbuild-remote-worker@${COMPOESR_HOST}:8700
