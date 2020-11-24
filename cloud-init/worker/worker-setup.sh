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
tee /etc/yum.repos.d/osbuild.repo > /dev/null << EOF
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
retry dnf -y install jq osbuild-composer-worker python3 unzip

# Set up the AWS CLI.
pushd /tmp
  curl --retry 5 -Ls -o awscli.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
  unzip awscli.zip
  aws/install
popd

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
