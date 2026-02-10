#!/bin/bash
set -e

echo "======================================="
echo " Kubernetes Cluster Tooling & Add-ons "
echo "======================================="

# -----------------------------
# Sanity check
# -----------------------------
kubectl get nodes >/dev/null 2>&1 || {
  echo "ERROR: kubectl not connected to cluster"
  echo "Run aws eks update-kubeconfig first"
  exit 1
}

# -----------------------------
# Helm (official)
# -----------------------------
if ! command -v helm >/dev/null 2>&1; then
  echo "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# -----------------------------
# Argo CD CLI (official docs)
# -----------------------------
if ! command -v argocd >/dev/null 2>&1; then
  echo "Installing Argo CD CLI..."
  ARCH=$(uname -m)
  [[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
  [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"

  VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest \
    | grep tag_name | cut -d '"' -f 4)

  curl -sSL -o argocd \
    "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-${ARCH}"

  chmod +x argocd
  sudo mv argocd /usr/local/bin/argocd
fi

# -----------------------------
# Install Argo CD Server (official)
# -----------------------------
echo "Installing Argo CD Server..."
kubectl create namespace argocd || true

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose Argo CD
echo "Exposing Argo CD via LoadBalancer..."
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'

# -----------------------------
# Gateway API
# -----------------------------
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml || true

# -----------------------------
# Helm repositories
# -----------------------------
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add elastic https://helm.elastic.co
helm repo update

# -----------------------------
# Prometheus + Grafana
# -----------------------------
echo "Installing Prometheus & Grafana..."
kubectl create namespace monitoring || true

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring

# Expose Prometheus
echo "Exposing Prometheus via LoadBalancer..."
kubectl patch svc prometheus-kube-prometheus-prometheus \
  -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}' || true

# Expose Grafana
echo "Exposing Grafana via LoadBalancer..."
kubectl patch svc prometheus-kube-prometheus-grafana \
  -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}' || true

# -----------------------------
# ELK Stack
# -----------------------------
echo "Installing ELK Stack..."
kubectl create namespace logging || true

helm upgrade --install elasticsearch elastic/elasticsearch -n logging
helm upgrade --install logstash elastic/logstash -n logging
helm upgrade --install kibana elastic/kibana -n logging
helm upgrade --install filebeat elastic/filebeat -n logging

# Expose Kibana
echo "Exposing Kibana via LoadBalancer..."
kubectl patch svc kibana-kibana \
  -n logging \
  -p '{"spec": {"type": "LoadBalancer"}}' || true

# -----------------------------
# Access Info
# -----------------------------
echo
echo "======================================="
echo " LoadBalancer Access Endpoints "
echo "======================================="
kubectl get svc -n argocd
kubectl get svc -n monitoring
kubectl get svc -n logging

echo
echo "======================================="
echo " Kubernetes Cluster Setup Completed ✅ "
echo "======================================="
