#!/bin/bash
set -e

echo "======================================="
echo " EC2 Host DevOps Tool Installation "
echo "======================================="

# -----------------------------
# Detect architecture
# -----------------------------
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  ARCH="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# -----------------------------
# Detect package manager
# -----------------------------
if command -v apt >/dev/null 2>&1; then
  PKG_MANAGER="apt"
elif command -v yum >/dev/null 2>&1; then
  PKG_MANAGER="yum"
else
  echo "Unsupported package manager"
  exit 1
fi

# -----------------------------
# Base dependencies
# -----------------------------
echo "Installing base dependencies..."
if [[ "$PKG_MANAGER" == "apt" ]]; then
  sudo apt update -y
  sudo apt install -y curl unzip ca-certificates gnupg lsb-release
else
  sudo yum install -y curl unzip ca-certificates gnupg
fi

# -----------------------------
# kubectl
# -----------------------------
if ! command -v kubectl >/dev/null 2>&1; then
  echo "Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
  sudo install -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
fi

# -----------------------------
# AWS CLI v2
# -----------------------------
if ! command -v aws >/dev/null 2>&1; then
  echo "Installing AWS CLI..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o awscliv2.zip
  unzip -q awscliv2.zip
  sudo ./aws/install
  rm -rf aws awscliv2.zip
fi

# -----------------------------
# eksctl
# -----------------------------
if ! command -v eksctl >/dev/null 2>&1; then
  echo "Installing eksctl..."
  curl -sLO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_${ARCH}.tar.gz"
  tar -xzf eksctl_Linux_${ARCH}.tar.gz
  sudo mv eksctl /usr/local/bin/
  rm -f eksctl_Linux_${ARCH}.tar.gz
fi

# -----------------------------
# Docker (official)
# -----------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker ubuntu
fi

# -----------------------------
# Versions
# -----------------------------
echo "======================================="
echo " Installed EC2 Host Tools "
echo "======================================="
kubectl version --client 2>/dev/null || kubectl version
aws --version
eksctl version
docker --version

echo "======================================="
echo " EC2 Host Setup Completed ✅ "
echo " Logout & login for Docker access "
echo "======================================="
