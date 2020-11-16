# Set the hostname to the hostname passed by terraform.
hostnamectl set-hostname $SYSTEM_HOSTNAME

dnf -y install cockpit osbuild-composer
systemctl enable --now cockpit.socket
systemctl enable --now osbuild-composer.socket
