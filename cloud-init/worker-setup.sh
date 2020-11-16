# Set the hostname to the hostname passed by terraform.
hostnamectl set-hostname $SYSTEM_HOSTNAME

dnf -y upgrade
