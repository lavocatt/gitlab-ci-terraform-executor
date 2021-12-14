#!/bin/bash

sudo dnf install -y https://gitlab-runner-downloads.s3.amazonaws.com/latest/rpm/gitlab-runner_amd64.rpm git-core dnf-plugins-core epel-release
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/$release/hashicorp.repo
sudo dnf install -y terraform awscli
