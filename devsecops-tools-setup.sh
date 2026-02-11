#!/bin/bash
set -e

echo "================================================"
echo " DevSecOps Complete Setup (Final Stable Version)"
echo " Jenkins | SonarQube | Trivy | Docker | AWS CLI | kubectl"
echo "================================================"

# -----------------------------
# Ensure Ubuntu
# -----------------------------
if ! command -v apt >/dev/null 2>&1; then
  echo "❌ This script supports Ubuntu only"
  exit 1
fi

# -----------------------------
# Update System
# -----------------------------
sudo apt update -y
sudo apt install -y \
  curl \
  wget \
  gnupg \
  ca-certificates \
  lsb-release \
  unzip \
  software-properties-common

# -----------------------------
# Install Docker (Official Repo)
# -----------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt update -y
  sudo apt install -y docker-ce docker-ce-cli containerd.io
fi

sudo systemctl enable docker
sudo systemctl start docker

# -----------------------------
# Fix Docker Permissions
# -----------------------------
echo "Configuring Docker permissions..."

ACTUAL_USER=${SUDO_USER:-$USER}
sudo usermod -aG docker "$ACTUAL_USER"

# -----------------------------
# Install Java 21
# -----------------------------
if ! java -version 2>&1 | grep -q "21"; then
  echo "Installing Java 21..."
  sudo apt install -y openjdk-21-jdk
fi

# -----------------------------
# Install Jenkins
# -----------------------------
if ! systemctl list-unit-files | grep -q jenkins.service; then
  echo "Installing Jenkins..."

  curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key \
    | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

  echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ \
    | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

  sudo apt update -y
  sudo apt install -y jenkins

  sudo systemctl enable jenkins
  sudo systemctl start jenkins
fi

# Add Jenkins to Docker group
if id "jenkins" &>/dev/null; then
  sudo usermod -aG docker jenkins
  sudo systemctl restart jenkins
fi

# -----------------------------
# Install AWS CLI v2
# -----------------------------
if ! command -v aws >/dev/null 2>&1; then
  echo "Installing AWS CLI v2..."

  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -o awscliv2.zip
  sudo ./aws/install
  rm -rf aws awscliv2.zip
fi

# -----------------------------
# Install kubectl
# -----------------------------
if ! command -v kubectl >/dev/null 2>&1; then
  echo "Installing kubectl..."

  KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)

  curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
fi

# -----------------------------
# Install Trivy
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
fi

# -----------------------------
# Install SonarQube (Docker LTS)
# -----------------------------
if ! sudo docker ps -a --format '{{.Names}}' | grep -q "^sonarqube$"; then
  echo "Installing SonarQube..."

  sudo docker volume create sonarqube_data
  sudo docker volume create sonarqube_extensions
  sudo docker volume create sonarqube_logs

  sudo docker run -d \
    --name sonarqube \
    --restart unless-stopped \
    -p 9000:9000 \
    -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
    -v sonarqube_data:/opt/sonarqube/data \
    -v sonarqube_extensions:/opt/sonarqube/extensions \
    -v sonarqube_logs:/opt/sonarqube/logs \
    sonarqube:lts
fi

# -----------------------------
# Final Restart (Safety)
# -----------------------------
sudo systemctl restart docker
sudo systemctl restart jenkins

# -----------------------------
# Display Installed Versions
# -----------------------------
echo
echo "================================================"
echo " Installed Versions "
echo "================================================"
docker --version
java -version
aws --version
kubectl version --client
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
echo " Setup Completed Successfully ✅"
echo "================================================"
echo " IMPORTANT:"
echo " 1. Logout & login again to use docker without sudo"
echo " 2. Jenkins has been restarted"
echo "================================================"
