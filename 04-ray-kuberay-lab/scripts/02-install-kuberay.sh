#!/bin/bash
# ==============================================================================
# Install KubeRay operator (Helm) — installs CRDs + controller in kuberay-system
# ==============================================================================
set -e

OPERATOR_NS="kuberay-system"
# Pin chart version for reproducible classes (see https://github.com/ray-project/kuberay/releases)
HELM_CHART_VERSION="${KUBERAY_HELM_VERSION:-1.1.0}"

echo "=============================================="
echo "  Step 2: Install KubeRay operator (Helm)"
echo "=============================================="
echo "  Namespace: $OPERATOR_NS"
echo "  Chart:     kuberay/kuberay-operator v$HELM_CHART_VERSION"
echo ""

helm repo add kuberay https://ray-project.github.io/kuberay-helm/ 2>/dev/null || true
helm repo update kuberay

helm upgrade --install kuberay-operator kuberay/kuberay-operator \
  --namespace "$OPERATOR_NS" \
  --create-namespace \
  --version "$HELM_CHART_VERSION" \
  --wait \
  --timeout 10m

echo ""
echo "Waiting for operator Deployment..."
DEPLOY=$(kubectl get deploy -n "$OPERATOR_NS" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$DEPLOY" ]; then
  kubectl rollout status "deployment/$DEPLOY" -n "$OPERATOR_NS" --timeout=300s
else
  echo "⚠️  No Deployment found yet in $OPERATOR_NS — check: kubectl get all -n $OPERATOR_NS"
fi

echo ""
kubectl get pods -n "$OPERATOR_NS"
echo ""
echo "=============================================="
echo "  ✅ KubeRay operator ready"
echo "  Next: ./03-deploy-ray-cluster.sh"
echo "=============================================="
