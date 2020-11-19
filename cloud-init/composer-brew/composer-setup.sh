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
ca = "/etc/osbuild-composer/ca.cert.pem"

[worker]
allowed_domains = [ "team.osbuild.org", "worker.brew.osbuild.org" ]
ca = "/etc/osbuild-composer/ca.cert.pem"
EOF

# Deploy the composer CA certificate.
tee ${COMPOSER_DIR}/ca-cert.pem > /dev/null << EOF
-----BEGIN CERTIFICATE-----
MIIDDTCCAfWgAwIBAgIUP3P3f35PFRNuoftzc9L96DhTodAwDQYJKoZIhvcNAQEL
BQAwFjEUMBIGA1UEAwwLb3NidWlsZC5vcmcwHhcNMjAwOTEzMTYyMDU3WhcNMzAw
OTExMTYyMDU3WjAWMRQwEgYDVQQDDAtvc2J1aWxkLm9yZzCCASIwDQYJKoZIhvcN
AQEBBQADggEPADCCAQoCggEBAMBpkYQXISLc8KYjMQYgzpQ9CA3RK2gHD0qaqsv8
aRcVC66S9fHqEE1iLUXO702Qz5skjh3zqLyGR8wRV//cI1b1r0UyZScLZ3W7UZrC
444fcz3MyxlSzWUYSPgBIKhgA8qmrZR1ofadrxuRL+snFDIkx3w+c1JeUn2cl0Wi
UtX2GGVCFWMOaofDkXUCFuKHwJQgFLtsHCZYcfvWVHZZ6N8wGp2QZY29c8umpj1P
PFlXC8daZLMaXYbE0MItV0CHJpwGIpbynmYTl+sFuvl4oTmrxz/yxzpDvVMOrAIm
xok7rUmTudDeESRBOgA1KuaMRTuaIpQo2dovq+01Ff3AN2UCAwEAAaNTMFEwHQYD
VR0OBBYEFJ7e6X3y0dolq/JbVibIiwdnSP+6MB8GA1UdIwQYMBaAFJ7e6X3y0dol
q/JbVibIiwdnSP+6MA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEB
AFzv7ieKG9lZKrB2MmZhAqHILylaOyVq77G9BMRTFspZu40r7GTwcDhvh5ECoHQb
lku0X5OXgDvXsBpoFHrv0KOIlS7UJ1v04k/JYgXw+ljTTs/9zpn8RVlmpu/GMOM5
QbGP+Nj5Zs5fGFWhN7M25QkU82JlxeJAlQxHClCPexRCMa1y5p7Tng80KJWtyPP9
tSgMBp75UReo45E8PJrJp3hyo4Rx9RQGkrycRIwfBHvkxMJfnsc7Y/v5iuF8mxMz
3tbJ9+JyEAuHz1bGuqCX+qJQTTt/Qo62vGWaI9SVKbS8aXLC2N6qcibqr58f4DJD
JslM/7psyr1o5ttbBn6Y5As=
-----END CERTIFICATE-----
EOF

# Deploy the composer key and certificate.
tee ${COMPOSER_DIR}/composer-crt.pem > /dev/null << EOF
${COMPOSER_BREW_CERT}
EOF
tee ${COMPOSER_DIR}/composer-key.pem > /dev/null << EOF
${COMPOSER_BREW_KEY}
EOF

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
systemctl enable --now osbuild-composer.socket

# Prepare osbuild-composer's remote worker services and sockets.
# NOTE(mhayden): Enable these and disable the socket above once we have
# certificates and keys provisioned.
#systemctl mask osbuild-worker@1.service
#systemctl enable --now osbuild-remote-worker.socket
#systemctl enable --now osbuild-composer-api.socket
