#!/bin/bash
set -euo pipefail

# Add SSH access
sudo mkdir -p /home/centos/.ssh
sudo tee /home/centos/.ssh/authorized_keys >/dev/null <<EOT
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPB1jFl4p6FTBixHT6wOk6X8nj/Z7eoPNQE/M0wK485K ondrej
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAAw68oI4pLPm4CDJ3Ya+wu4FaxX+h16X5EkxR954KYYrN4xyb/DMarQ0U5CR7kWX+30eFx7RgsnqmN8vKTw9q8i28eI7w8RauiT/Dljfh0d/qD5O096ei0EMLt+gryDhoaPUUyF66RpSC/OGluQo/e4JFK8p6cvltoWORPpd9tKpFQpmMSD2kmPGqkmM6liNq/dbwXStXFzpHbU/UljrP0FVwwGygQMpPAtpeyCREhMPYJBDYfGNtDq1scjcgrhSo95/bu7+KMoX8DWOhVM5zp3S6PWTfCirH/kXpsEfpqY8QsOYJYJukq9MOLCKQ76deFyCuM0EoIw6c/0bw1bb9h1/oSJfGPSrBjokppmfA+3EVv/XeC19JyMmVgXLKbyHwlBWjfFYxz0FOHFYxHnvK697zamiiQnUF0OAHT5Sidnp1p4Cnnw2vIKqz4KCFyQ4Gjc3asAMe6B8A6w8pT1rTXWier58w/CJdNYTtvpTjO2vPwxzANxGXpXWjiNlvylmwLikYlstagCZo74A2hXlLOf36Tq0Er9mHLfDag5c+Clu0QAT94uXnJlNigF59vwsnhoAhQ9K47vuFJeTKqVhNZ7AE2xezIVpmklMFBiRhitOg+EQce+v7eiqX/H+YQXRtQRR2gu2+q42i44UEU3bQltY5ub6ZKgYIMMTgRYhmjKT sanne
EOT

sudo chown -R centos:centos /home/centos/.ssh
sudo chmod 600 /home/centos/.ssh/authorized_keys
sudo chmod 700 /home/centos/.ssh

# Upgrade everything
sudo dnf upgrade -y

# Add extra repositories
sudo dnf install -y epel-release
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo curl -Lo /etc/yum.repos.d/gitlab-runner.repo "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/config_file.repo?os=centos&dist=8&source=script"

# Install needed packages
sudo dnf install -y terraform awscli jq gitlab-runner git-core python3-jinja2

# Stop the service for now
sudo systemctl disable --now gitlab-runner

# Load secrets
aws --region us-east-1 secretsmanager get-secret-value \
  --secret-id "${secret_arn}" | jq -r ".SecretString" > ~/secrets

# Save SSH key
sudo mkdir /home/gitlab-runner/.ssh || true
jq -r ".ssh_key" <~/secrets | base64 -d | sudo tee /home/gitlab-runner/.ssh/id_rsa >/dev/null

sudo chown -R gitlab-runner:gitlab-runner /home/gitlab-runner/.ssh
sudo chmod 400 /home/gitlab-runner/.ssh/id_rsa

# Cloning the executor
sudo git clone https://github.com/osbuild/gitlab-ci-terraform-executor.git /home/gitlab-runner/gitlab-ci-terraform-executor
sudo chown -R gitlab-runner:gitlab-runner /home/gitlab-runner/gitlab-ci-terraform-executor

# Establish the config
sudo mkdir /home/gitlab-runner/.gitlab-runner
tee /tmp/config-maker >/dev/null <<EOT
import jinja2
import json
import sys

with open(sys.argv[-1]) as f:
    secrets = json.load(f)
jinja_template = jinja2.Template(sys.stdin.read(), keep_trailing_newline=True)

print(jinja_template.render(secrets))
EOT

git clone https://github.com/osbuild/gitlab-ci-config.git /tmp/gitlab-ci-config
sudo python3 /tmp/config-maker ~/secrets </tmp/gitlab-ci-config/config.toml.tpl >/home/gitlab-runner/.gitlab-runner/config.toml
sudo chown -R gitlab-runner:gitlab-runner /home/gitlab-runner/.gitlab-runner

# Re-define and start the service
sudo tee /etc/systemd/system/gitlab-runner.service >/dev/null <<EOT
[Unit]
Description=GitLab Runner
After=syslog.target network.target

[Service]
StartLimitInterval=5
StartLimitBurst=10
ExecStart=/usr/bin/gitlab-runner run
Restart=always
RestartSec=120
User=gitlab-runner
Group=gitlab-runner

[Install]
WantedBy=multi-user.target
EOT

sudo systemctl daemon-reload
sudo systemctl enable --now gitlab-runner

# Remove secrets
rm ~/secrets
