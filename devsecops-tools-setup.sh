#!/bin/bash
set -e

echo "================================================"
echo " DevSecOps Tools Setup (2026 Ready)"
echo " Jenkins | SonarQube | Trivy | Docker | Java 21"
echo "================================================"

# -----------------------------
# OS check (Ubuntu only)
# -----------------------------
if ! command -v apt >/dev/null 2>&1; then
  echo "ERROR: This script supports Ubuntu only"
  exit 1
fi

# -----------------------------
# Base dependencies
# -----------------------------
echo "Installing base dependencies..."
sudo apt update -y
sudo apt install -y \
  curl \
  wget \
  gnupg \
  ca-certificates \
  lsb-release \
  unzip \
  apt-transport-https \
  software-properties-common

# -----------------------------
# Docker (official)
# https://docs.docker.com/engine/install/ubuntu/
# -----------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker ubuntu
else
  echo "Docker already installed"
fi

# -----------------------------
# Java 21 (LTS)
# -----------------------------
if ! java -version 2>&1 | grep -q "21"; then
  echo "Installing Java 21 (LTS)..."
  sudo apt install -y openjdk-21-jre
else
  echo "Java 21 already installed"
fi

# -----------------------------
# Jenkins (OFFICIAL – 2026 KEY)
# https://www.jenkins.io/doc/book/installing/linux/
# -----------------------------
if ! systemctl list-units --type=service | grep -q jenkins; then
  echo "Installing Jenkins..."

  curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
    | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

  echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ \
    | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

  sudo apt update -y
  sudo apt install -y jenkins

  sudo systemctl enable jenkins
  sudo systemctl start jenkins
else
  echo "Jenkins already installed"
fi

# -----------------------------
# SonarQube (Official Docker Image – LTS)
# https://docs.sonarsource.com/sonarqube/latest/setup/install-server/
# -----------------------------
if ! docker ps -a --format '{{.Names}}' | grep -q "^sonarqube$"; then
  echo "Installing SonarQube (Docker – LTS)..."

  docker volume create sonarqube_data
  docker volume create sonarqube_extensions
  docker volume create sonarqube_logs

  docker run -d \
    --name sonarqube \
    --restart unless-stopped \
    -p 9000:9000 \
    -v sonarqube_data:/opt/sonarqube/data \
    -v sonarqube_extensions:/opt/sonarqube/extensions \
    -v sonarqube_logs:/opt/sonarqube/logs \
    sonarqube:lts
else
  echo "SonarQube already running"
fi

# -----------------------------
# Trivy (Official Aqua Security Repo)
# https://aquasecurity.github.io/trivy/
# -----------------------------
if ! command -v trivy >/dev/null 2>&1; then
  echo "Installing Trivy..."

  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | sudo tee /etc/apt/keyrings/trivy.asc > /dev/null

  echo deb [signed-by=/etc/apt/keyrings/trivy.asc] \
    https://aquasecurity.github.io/trivy-repo/deb \
    $(lsb_release -sc) main \
    | sudo tee /etc/apt/sources.list.d/trivy.list

  sudo apt update -y
  sudo apt install -y trivy
else
  echo "Trivy already installed"
fi

# -----------------------------
# Versions & Access Info
# -----------------------------
echo
echo "================================================"
echo " Installed Versions "
echo "================================================"
docker --version
java -version
trivy --version
jenkins --version || true

echo
echo "================================================"
echo " Access URLs "
echo "================================================"
echo " Jenkins   : http://<EC2-PUBLIC-IP>:8080"
echo " SonarQube : http://<EC2-PUBLIC-IP>:9000"

echo
echo " Initial Jenkins Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword || true

echo
echo "================================================"
echo " Installation Completed Successfully ✅ "
echo " Logout & login again for Docker access "
echo "================================================"
