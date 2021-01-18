# Variables for the script.
EBS_STORAGE=/dev/nvme1n1
STATE_DIR=/var/lib/osbuild-composer
COMPOSER_DIR=/etc/osbuild-composer

# TODO(mhayden): Remove this key once we know everything is working.
tee --append /home/ec2-user/.ssh/authorized_keys > /dev/null << EOF
# SSH keys for obudai and mhayden
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCxjfFIIlGfCn9iclHymWrEBrTU2lL6tkSGT1ep7dCPzw1jY6WnhQlPXMpePriNxNXlG8cWO9/RFpBd0z9FwNy+kfgh9fuyNY49I+Ma6OyTVBg5hNoFxfRXG5iHtc/SQlnbEFiKpSk4lipo4QZtBtmgAqgkSA6Dzhygb6u5M9ixTIx4WBjuSM0GXQzNjpefyiWu+sIR+h2UrQkKABuuIYQbrjl+FhVmaLvrvyTO2usOtvnYBjhbPwyO72WPjapKd/9hTaqPE1wFy6UF2nXc4Pgw0giQb6sibFTz7NTexW35Q98qpQOWMYKcpgZrlSaHHKZSMhtzO7MdZrOLFUXoS1AeAy4ghtcNrOBTlb5SvP73zz0qBRF2cCO4O0wp5wwqPhvw2ntb3pTLPtdetJ+V50QPnpnXySSnZp2zFwce21bXx67nh9lnhLrZgje7coQnPAFx/cl36ESJygiuPcBw+k18YulYMXUqaBtkwJLkRjDpjTX2e5MJ16oD7sJHc4/W5kyfLvdMsVhdq1CXHGVVOpzogb095VYi0RXFpnZR/1eVgC/R+WVytYfY80rfVOcdAo2GZfnJ5zYRUXJJ9MZkanxx3E7UOikEJN9sUj200z6Cyy0IfIqTbJ1B5f7fd3acRrL4DcYUdFI/1ByNW6F1j7cZiAGOJKNbzXF0T3tf8x0e1Q== major@redhat.com
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPB1jFl4p6FTBixHT6wOk6X8nj/Z7eoPNQE/M0wK485K obudai@redhat.com
EOF

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
  --endpoint-url ${SECRETS_MANAGER_ENDPOINT_URL} \
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
