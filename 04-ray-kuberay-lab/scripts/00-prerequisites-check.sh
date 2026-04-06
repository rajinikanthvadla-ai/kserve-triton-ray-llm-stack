#!/bin/bash
# ==============================================================================
# Prerequisites: kubectl, helm, curl, jq (+ eksctl if creating EKS)
# ==============================================================================
set -e

echo "=============================================="
echo "  Ray + KubeRay lab — prerequisites"
echo "=============================================="
echo ""

for cmd in kubectl helm curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Missing: $cmd"
    exit 1
  fi
  echo "  ✅ $cmd"
done

if command -v eksctl &>/dev/null; then
  echo "  ✅ eksctl"
else
  echo "  ⚠️  eksctl not found (only needed for ./01-create-eks-cluster.sh)"
fi

echo ""
echo "Cluster:"
kubectl cluster-info
echo ""
kubectl get nodes -o wide 2>/dev/null || true
echo ""
echo "=============================================="
echo "  Next: ./02-install-kuberay.sh"
echo "  (No cluster? ./01-create-eks-cluster.sh first.)"
echo "=============================================="
