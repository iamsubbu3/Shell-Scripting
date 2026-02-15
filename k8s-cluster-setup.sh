#!/bin/bash
set -euo pipefail

echo "===================================================="
echo " ZERO-FAIL Monitoring + GitOps + ELK Setup"
echo " ArgoCD + Prometheus + Grafana + ELK"
echo "===================================================="

NAMESPACE_MON="monitoring"
NAMESPACE_ARGO="argocd"

# ----------------------------------------------------
# 1️⃣ Cluster Validation
# ----------------------------------------------------
echo "🔎 Checking cluster connectivity..."
kubectl cluster-info >/dev/null
echo "✅ Cluster reachable"

# ----------------------------------------------------
# 2️⃣ Helm install check
# ----------------------------------------------------
if ! command -v helm >/dev/null; then
  echo "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# jq needed for release cleanup
if ! command -v jq >/dev/null; then
  echo "Installing jq..."
  apt-get update && apt-get install -y jq
fi

# ----------------------------------------------------
# 3️⃣ Helm repositories
# ----------------------------------------------------
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

# ----------------------------------------------------
# 4️⃣ Namespaces
# ----------------------------------------------------
kubectl create namespace $NAMESPACE_ARGO --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $NAMESPACE_MON --dry-run=client -o yaml | kubectl apply -f -

# ----------------------------------------------------
# 5️⃣ HELPER FUNCTIONS
# ----------------------------------------------------
wait_pods () {
  NS=$1
  echo "⏳ Waiting for pods in namespace $NS ..."
  kubectl wait --for=condition=Ready pods --all -n $NS --timeout=900s || true
}

cleanup_pending_release () {
  REL=$1
  NS=$2

  STATUS=$(helm list -n $NS --all -o json | jq -r ".[] | select(.name==\"$REL\") | .status" || true)

  if [[ "$STATUS" == "pending-install" || "$STATUS" == "pending-upgrade" || "$STATUS" == "failed" ]]; then
    echo "⚠️ Cleaning stuck release: $REL"
    helm uninstall $REL -n $NS || true
  fi
}

# ----------------------------------------------------
# 6️⃣ ArgoCD
# ----------------------------------------------------
cleanup_pending_release argocd $NAMESPACE_ARGO

echo "🚀 Installing ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
  -n $NAMESPACE_ARGO \
  -f values/argocd-values.yaml \
  --wait --timeout 10m --atomic

# ----------------------------------------------------
# 7️⃣ Prometheus + Grafana
# ----------------------------------------------------
cleanup_pending_release monitoring $NAMESPACE_MON

echo "🚀 Installing Prometheus + Grafana..."
helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  -n $NAMESPACE_MON \
  -f values/prometheus-values.yaml \
  --wait --timeout 15m --atomic

# ----------------------------------------------------
# 8️⃣ ELK STACK (YAML APPLY)
# ----------------------------------------------------
echo "🚀 Applying ELK Stack manifests..."

kubectl apply -f elk/namespace.yaml
kubectl apply -f elk/deployment-elasticsearch.yaml
kubectl apply -f elk/svc-elasticsearch.yaml
kubectl apply -f elk/deployment-kibana.yaml
kubectl apply -f elk/svc-kibana.yaml
kubectl apply -f elk/configmap-logstash.yaml
kubectl apply -f elk/deployment-logstash.yaml
kubectl apply -f elk/svc-logstash.yaml
kubectl apply -f elk/configmap-filebeat.yaml
kubectl apply -f elk/deployment-filebeat.yaml

echo "✅ ELK manifests applied"

# ----------------------------------------------------
# 9️⃣ Final health checks
# ----------------------------------------------------
wait_pods $NAMESPACE_ARGO
wait_pods $NAMESPACE_MON
wait_pods observability

# ----------------------------------------------------
# 🔟 Passwords
# ----------------------------------------------------
echo ""
echo "🔐 ArgoCD Password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""

echo ""
echo "🔐 Grafana Password:"
kubectl -n monitoring get secret monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
echo ""

echo "===================================================="
echo "✅ INSTALL COMPLETED"
echo " ArgoCD + Prometheus + Grafana + ELK"
echo "===================================================="
