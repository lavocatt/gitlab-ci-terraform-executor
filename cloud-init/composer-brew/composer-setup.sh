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
tee /etc/osbuild-composer/osbuild-composer.toml > /dev/null << EOF
[koji]
allowed_domains = [ "team.osbuild.org", "hub.brew.osbuild.org", "worker.brew.osbuild.org" ]
ca = "/etc/osbuild-composer/ca.cert.pem"

[worker]
allowed_domains = [ "team.osbuild.org", "worker.brew.osbuild.org" ]
ca = "/etc/osbuild-composer/ca.cert.pem"
EOF

# Forward systemd journal to the console for easier viewing.
tee /etc/osbuild-composer/osbuild-composer.toml > /dev/null << EOF
[Journal]
ForwardToConsole=yes
MaxLevelConsole=6
EOF

# Ensure the SELinux contexts are correct.
restorecon -Rv /etc/systemd/journald.conf.d/forward-to-console.conf

# Restart journald to pick up the console log change.
systemctl restart systemd-journald

# Start osbuild-composer and a default worker.
# NOTE(mhayden): Use a remote worker setup later once we know this works.
systemctl enable --now osbuild-composer.socket
