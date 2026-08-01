#!/bin/bash

set -e

echo "📦 Installing dependencies for K3d and Argo CD..."

if command -v dnf &>/dev/null; then
  PKG_MGR=dnf
elif command -v yum &>/dev/null; then
  PKG_MGR=yum
else
  echo "ERROR: yum or dnf is required (CentOS/RHEL expected)."
  exit 1
fi

sudo $PKG_MGR install -y \
  curl wget ca-certificates yum-utils device-mapper-persistent-data lvm2

echo "🐳 Installing Docker..."

sudo $PKG_MGR remove -y \
  docker docker-client docker-client-latest docker-common \
  docker-latest docker-latest-logrotate docker-logrotate docker-engine \
  2>/dev/null || true

curl -fsSL https://get.docker.com | sudo bash

sudo systemctl enable --now docker
sudo usermod -aG docker $USER

echo "📦 Installing kubectl..."

KUBECTL_VERSION=$(curl -s https://dl.k8s.io/release/stable.txt)

if [[ ! "$KUBECTL_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "⚠️  Failed to fetch latest kubectl version, using fallback v1.30.1"
  KUBECTL_VERSION="v1.30.1"
fi

curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

echo "📦 Installing k3d..."

curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "📦 Installing Argo CD CLI..."

curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

echo "✅ All tools installed successfully!"
echo "⚠️  Please run 'newgrp docker' or restart your shell to use Docker without sudo."
