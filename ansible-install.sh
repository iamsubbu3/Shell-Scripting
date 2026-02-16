#!/bin/bash
set -e

echo "==============================================="
echo " Installing Ansible + Python3-pip + Docker Collection "
echo "==============================================="

# -----------------------------
# Update system
# -----------------------------
echo "Updating package index..."
sudo apt update -y

# -----------------------------
# Install required dependencies
# -----------------------------
echo "Installing required packages..."
sudo apt install -y software-properties-common python3-pip

# -----------------------------
# Add Ansible official PPA
# -----------------------------
echo "Adding Ansible official PPA..."
sudo add-apt-repository --yes --update ppa:ansible/ansible

# -----------------------------
# Install Ansible
# -----------------------------
echo "Installing Ansible..."
sudo apt install -y ansible

# -----------------------------
# Install Ansible Galaxy Docker Collection
# -----------------------------
echo "Installing community.docker collection..."
ansible-galaxy collection install community.docker

# -----------------------------
# Verify installations
# -----------------------------
echo
echo "==============================================="
echo " Installation Completed Successfully ✅ "
echo "==============================================="

echo "Ansible version:"
ansible --version

echo
echo "Python pip version:"
pip3 --version
