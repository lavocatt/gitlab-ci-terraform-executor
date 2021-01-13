# Variables for the script.
EBS_STORAGE=/dev/nvme1n1
STATE_DIR=/var/lib/osbuild-composer
COMPOSER_DIR=/etc/osbuild-composer

# Add mhayden's SSH key temporarily.
curl https://github.com/major.keys >> /home/ec2-user/.ssh/authorized_keys

# Deploy a customized osbuild-composer configuration.
mkdir ${COMPOSER_DIR}
tee ${COMPOSER_DIR}/osbuild-composer.toml > /dev/null << EOF
[koji]
allowed_domains = [ "team.osbuild.org", "hub.brew.osbuild.org", "worker.brew.osbuild.org" ]
ca = "/etc/osbuild-composer/ca-crt.pem"

[worker]
allowed_domains = [ "team.osbuild.org", "worker.brew.osbuild.org" ]
ca = "/etc/osbuild-composer/ca-crt.pem"
EOF

# Deploy the osbuild CA certificate.
base64 -d - <<< ${OSBUILD_CA_CERT} > ${COMPOSER_DIR}/ca-crt.pem

# Deploy the composer certificate.
base64 -d - <<< ${COMPOSER_CERT} > ${COMPOSER_DIR}/composer-crt.pem

# Deploy the composer key.
/usr/local/bin/aws secretsmanager get-secret-value \
  --secret-id ${COMPOSER_SSL_KEYS_ARN} | jq -r ".SecretString" > /tmp/composer_keys.json
jq -r ".composer_key" /tmp/composer_keys.json | base64 -d - > ${COMPOSER_DIR}/composer-key.pem
rm -f /tmp/composer_keys.json

# Set up storage on composer.
if ! grep ${STATE_DIR} /proc/mounts; then
  # Ensure EBS is fully connected first.
  for TIMER in {0..300}; do
    if stat $EBS_STORAGE; then
      break
    fi
    sleep 1
  done

  # Check if XFS filesystem is already made.
  if ! xfs_info $EBS_STORAGE; then
    mkfs.xfs $EBS_STORAGE
  fi

  # Make osbuild-composer state directory if missing.
  mkdir -p ${STATE_DIR}

  # Add to /etc/fstab and mount.
  echo "${EBS_STORAGE} ${STATE_DIR} xfs defaults 0 0" | tee -a /etc/fstab
  mount $EBS_STORAGE

  # Reset SELinux contexts.
  restorecon -Rv /var/lib

  # Set filesystem permissions.
  chown -R _osbuild-composer:_osbuild-composer ${STATE_DIR}

  # Verify that the storage is writable
  touch ${STATE_DIR}/.provisioning_check
  rm -f ${STATE_DIR}/.provisioning_check
fi

# Prepare osbuild-composer's remote worker services and sockets.
systemctl mask osbuild-worker@1.service
systemctl enable --now osbuild-remote-worker.socket
systemctl enable --now osbuild-composer-api.socket
