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

# Basic function to retry a command up to 5 times.
function retry {
    local count=0
    local retries=5
    until "$@"; do
        exit=$?
        count=$((count + 1))
        if [[ $count -lt $retries ]]; then
            echo "Retrying command..."
            sleep 1
        else
            echo "Command failed after ${retries} retries. Giving up."
            return $exit
        fi
    done
    return 0
}

# Variables for the script.
EBS_STORAGE=/dev/nvme1n1
STATE_DIR=/var/lib/osbuild-composer
COMPOSER_DIR=/etc/osbuild-composer

# Deploy the dnf repository file for osbuild-composer.
tee /etc/yum.repos.d/composer.repo > /dev/null << EOF
[composer]
name = osbuild-composer commit ${COMPOSER_COMMIT}
baseurl = http://osbuild-composer-repos.s3-website.us-east-2.amazonaws.com/osbuild-composer/rhel-8.3/x86_64/${COMPOSER_COMMIT}
enabled = 1
gpgcheck = 0
priority = 5
EOF

# Deploy the dnf repository file for osbuild.
# TODO(tgunders): drop this as soon as composer can be installed without the worker.
tee /etc/yum.repos.d/composer.repo > /dev/null << EOF
[osbuild]
name = osbuild commit ${OSBUILD_COMMIT}
baseurl = http://osbuild-composer-repos.s3-website.us-east-2.amazonaws.com/osbuild/rhel-8.3/x86_64/${OSBUILD_COMMIT}
enabled = 1
gpgcheck = 0
priority = 5
EOF

# Ensure we have an updated dnf cache.
retry dnf makecache

# Update all existing packages to their latest version.
retry dnf -y upgrade

# Install required packages.
retry dnf -y install jq osbuild-composer unzip

# Set up the AWS CLI.
pushd /tmp
  curl --retry 5 -Ls -o awscli.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
  unzip awscli.zip
  aws/install
popd

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

# Deploy the composer CA certificate.
base64 -d - <<< ${OSBUILD_CA_CERT} > ${COMPOSER_DIR}/ca-crt.pem

# Deploy the composer key and certificate.
/usr/local/bin/aws secretsmanager get-secret-value \
  --secret-id ${COMPOSER_SSL_KEYS_ARN} | jq -r ".SecretString" > /tmp/composer_keys.json
jq -r ".composer_key" /tmp/composer_keys.json | base64 -d - > ${COMPOSER_DIR}/composer-key.pem
jq -r ".composer_crt" /tmp/composer_keys.json | base64 -d - > ${COMPOSER_DIR}/composer-crt.pem
rm -f /tmp/composer_keys.json

# Ensure osbuild-composer's configuration files have correct ownership.
chown -R _osbuild-composer:_osbuild-composer $COMPOSER_DIR

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

# Start osbuild-composer and a default worker.
# NOTE(mhayden): Use a remote worker setup later once we know this works.
# systemctl enable --now osbuild-composer.socket

# Enable access logging for osbuild-composer.
mkdir /etc/systemd/system/osbuild-composer.service.d/
tee /etc/systemd/system/osbuild-composer.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/libexec/osbuild-composer/osbuild-composer -v
EOF
systemctl daemon-reload

# Prepare osbuild-composer's remote worker services and sockets.
systemctl mask osbuild-worker@1.service
systemctl enable --now osbuild-remote-worker.socket
systemctl enable --now osbuild-composer.socket
