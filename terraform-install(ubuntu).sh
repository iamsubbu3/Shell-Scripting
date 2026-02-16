#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo " Terraform Installation (Ubuntu/Debian)"
echo " Official HashiCorp APT Repository"
echo "=========================================="

# --------------------------------------------------
# 1️⃣ Install required dependencies
# --------------------------------------------------
echo "[1/6] Installing required packages..."
sudo apt-get update -y
sudo apt-get install -y gpg wget curl lsb-release

# --------------------------------------------------
# 2️⃣ Add HashiCorp GPG signing key (modern method)
# --------------------------------------------------
echo "[2/6] Adding HashiCorp GPG key..."
wget -O- https://apt.releases.hashicorp.com/gpg \
| sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# --------------------------------------------------
# 3️⃣ Verify key fingerprint (security check)
# --------------------------------------------------
# echo "[3/6] Verifying GPG fingerprint..."
# gpg --no-default-keyring \
#   --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
#   --fingerprint

# echo "Expected fingerprint:"
# echo "798A EC65 4E5C 1542 8C8E 42EE AA16 FCBC A621 E701"

# --------------------------------------------------
# 4️⃣ Add official HashiCorp repository
# --------------------------------------------------
echo "[4/6] Adding HashiCorp APT repository..."

CODENAME=$(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs)

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${CODENAME} main" \
| sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

# --------------------------------------------------
# 5️⃣ Update package list
# --------------------------------------------------
echo "[5/6] Updating package index..."
sudo apt-get update -y

# --------------------------------------------------
# 6️⃣ Install Terraform
# --------------------------------------------------
echo "[6/6] Installing Terraform..."
sudo apt-get install -y terraform

# --------------------------------------------------
# Verify installation
# --------------------------------------------------
echo ""
echo "✅ Terraform installed successfully!"
terraform -version
