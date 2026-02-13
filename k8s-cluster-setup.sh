#!/bin/bash
set -euo pipefail

echo "===================================================="
echo " Production Monitoring + Logging + GitOps Setup "
echo " ArgoCD + Prometheus + Grafana + ELK + Filebeat "
echo "===================================================="

# ----------------------------------------------------
# 1️⃣ Cluster Validation
# ----------------------------------------------------
if ! kubectl cluster-info &>/dev/null; then
  echo "❌ Cannot connect to Kubernetes cluster"
  exit 1
fi

echo "✅ Cluster reachable"
kubectl config current-context

# ----------------------------------------------------
# 2️⃣ Monitoring nodes check
# ----------------------------------------------------
if ! kubectl get nodes -l role=monitoring | grep -q Ready; then
  echo "❌ No monitoring nodes found"
  echo "Run:"
  echo "kubectl label nodes <node-name> role=monitoring"
  exit 1
fi

# ----------------------------------------------------
# 3️⃣ Install Helm
# ----------------------------------------------------
if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# ----------------------------------------------------
# 4️⃣ Helm repos
# ----------------------------------------------------
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add elastic https://helm.elastic.co || true

helm repo update

# ----------------------------------------------------
# 5️⃣ Namespaces
# ----------------------------------------------------
kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns monitoring --dry-run=client -o yaml | kubectl apply -f -

# ----------------------------------------------------
# 6️⃣ ArgoCD
# ----------------------------------------------------
helm upgrade --install argocd argo/argo-cd \
  -n argocd \
  -f values/argocd-values.yaml \
  --wait --timeout 10m

# ----------------------------------------------------
# 7️⃣ Prometheus + Grafana
# ----------------------------------------------------
helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values/prometheus-values.yaml \
  --wait --timeout 15m

# ----------------------------------------------------
# 8️⃣ Elasticsearch
# ----------------------------------------------------
helm upgrade --install elasticsearch elastic/elasticsearch \
  -n monitoring \
  -f values/elk-values.yaml \
  --wait --timeout 20m

# ----------------------------------------------------
# 9️⃣ Kibana
# ----------------------------------------------------
helm upgrade --install kibana elastic/kibana \
  -n monitoring \
  -f values/elk-values.yaml \
  --wait --timeout 10m

# ----------------------------------------------------
# 🔟 Logstash
# ----------------------------------------------------
helm upgrade --install logstash elastic/logstash \
  -n monitoring \
  -f values/logstash-values.yaml \
  --wait --timeout 10m

# ----------------------------------------------------
# 11️⃣ Filebeat
# ----------------------------------------------------
helm upgrade --install filebeat elastic/filebeat \
  -n monitoring \
  -f values/filebeat-values.yaml \
  --wait --timeout 10m

# ----------------------------------------------------
# 12️⃣ Rollout checks
# ----------------------------------------------------
kubectl rollout status deployment -n argocd --timeout=600s || true
kubectl rollout status deployment -n monitoring --timeout=900s || true

# ----------------------------------------------------
# 13️⃣ Passwords
# ----------------------------------------------------
echo ""
echo "ArgoCD Admin Password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""

echo ""
echo "Grafana Admin Password:"
kubectl -n monitoring get secret monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
echo ""

echo ""
echo "✅ Installation complete (ClusterIP services)"
