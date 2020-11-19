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
name = osbuild-composer commit ${COMMIT}
baseurl = http://osbuild-composer-repos.s3-website.us-east-2.amazonaws.com/osbuild-composer/rhel-8.3/x86_64/${COMMIT}
enabled = 1
gpgcheck = 0
priority = 5
EOF

# Ensure we have an updated dnf cache.
retry dnf makecache

# Update all existing packages to their latest version.
retry dnf -y upgrade

# Install required packages.
retry dnf -y install osbuild-composer

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
base64 -d - <<< ${COMPOSER_BREW_CA_CERT} > ${COMPOSER_DIR}/ca-crt.pem

# Deploy the composer key and certificate.
base64 -d - <<< ${COMPOSER_BREW_CERT} > ${COMPOSER_DIR}/composer-crt.pem
base64 -d - <<< ${COMPOSER_BREW_KEY} > ${COMPOSER_DIR}/composer-key.pem

# Ensure osbuild-composer's configuration files have correct ownership.
chown -R _osbuild-composer:_osbuild-composer $COMPOSER_DIR

# Forward systemd journal to the console for easier viewing.
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

# Prepare osbuild-composer's remote worker services and sockets.
# NOTE(mhayden): Enable these and disable the socket above once we have
# certificates and keys provisioned.
systemctl mask osbuild-worker@1.service
systemctl enable --now osbuild-remote-worker.socket
systemctl enable --now osbuild-composer-api.socket
