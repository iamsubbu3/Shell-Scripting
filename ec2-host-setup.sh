#!/bin/bash
set -e

echo "======================================="
echo " EC2 Host DevOps Tool Installation "
echo "======================================="

# -----------------------------
# Check Ubuntu
# -----------------------------
if ! command -v apt >/dev/null 2>&1; then
  echo "ERROR: This script supports Ubuntu only"
  exit 1
fi

# -----------------------------
# Detect Architecture
# -----------------------------
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  K8S_ARCH="amd64"
  AWS_ARCH="x86_64"
elif [[ "$ARCH" == "aarch64" ]]; then
  K8S_ARCH="arm64"
  AWS_ARCH="aarch64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# -----------------------------
# Base Dependencies
# -----------------------------
echo "Installing base dependencies..."
sudo apt update -y
sudo apt install -y \
  curl \
  unzip \
  ca-certificates \
  gnupg \
  lsb-release

# -----------------------------
# Install kubectl (Official)
# -----------------------------
if ! command -v kubectl >/dev/null 2>&1; then
  echo "Installing kubectl..."
  curl -fsSL -o kubectl \
    "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/${K8S_ARCH}/kubectl"

  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "kubectl already installed"
fi

# -----------------------------
# Install AWS CLI v2 (Official 2026 Method)
# -----------------------------
if ! command -v aws >/dev/null 2>&1; then
  echo "Installing AWS CLI v2..."

  curl -fsSL \
    "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" \
    -o awscliv2.zip

  unzip -q awscliv2.zip
  sudo ./aws/install

  rm -rf aws awscliv2.zip
else
  echo "AWS CLI already installed"
fi

# -----------------------------
# Install eksctl (Official)
# -----------------------------
if ! command -v eksctl >/dev/null 2>&1; then
  echo "Installing eksctl..."
  curl -fsSL -o eksctl.tar.gz \
    "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_${K8S_ARCH}.tar.gz"

  tar -xzf eksctl.tar.gz
  sudo mv eksctl /usr/local/bin/
  rm -f eksctl.tar.gz
else
  echo "eksctl already installed"
fi

# -----------------------------
# Install Docker (Official Script)
# -----------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker $USER
else
  echo "Docker already installed"
fi

# -----------------------------
# Versions Check
# -----------------------------
echo
echo "======================================="
echo " Installed EC2 Host Tools "
echo "======================================="
kubectl version --client 2>/dev/null || kubectl version
aws --version
eksctl version
docker --version

echo
echo "======================================="
echo " EC2 Host Setup Completed Successfully ✅ "
echo " Logout & login again for Docker access "
echo "======================================="
