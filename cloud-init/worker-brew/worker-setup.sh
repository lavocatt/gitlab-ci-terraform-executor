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

# Set up /etc/hosts
# TODO(mhayden): We need to convert this to DNS later when we launch.
<<< "${COMPOSER_BREW_ADDRESS} ${COMPOSER_BREW_HOST}" >> /etc/hosts

# Deploy the composer CA certificate.
mkdir ${COMPOSER_DIR}
base64 -d - <<< ${COMPOSER_BREW_CA_CERT} > ${COMPOSER_DIR}/ca-cert.pem

# Deploy the composer key and certificate.
base64 -d - <<< ${WORKER_BREW_CERT} > ${WORKER_DIR}/worker-crt.pem
base64 -d - <<< ${WORKER_BREW_KEY} > ${WORKER_DIR}/worker-key.pem

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

# Prepare osbuild-composer's remote worker services and sockets.
# NOTE(mhayden): Enable these and disable the socket above once we have
# certificates and keys provisioned.
systemctl enable --now osbuild-remote-worker@${COMPOSER_BREW_HOST}:8700
