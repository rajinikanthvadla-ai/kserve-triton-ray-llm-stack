#!/bin/bash
# ==============================================================================
# Create EKS cluster for this lab (optional — reuse any cluster with kubectl)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

CLUSTER_NAME="ray-kuberay-lab"
YAML_REGION=$(grep -E '^\s+region:' "$MANIFESTS_DIR/eks-cluster.yaml" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'")
REGION="${RAY_LAB_REGION:-${YAML_REGION:-ap-south-1}}"

echo "=============================================="
echo "  Step 1: EKS cluster (Ray + KubeRay lab)"
echo "=============================================="
echo "  Cluster: $CLUSTER_NAME  Region: $REGION"
echo ""

if eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null; then
  echo "⚠️  Cluster exists — updating kubeconfig..."
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
  exit 0
fi

eksctl create cluster -f "$MANIFESTS_DIR/eks-cluster.yaml"

kubectl get nodes -o wide
echo ""
echo "  Next: ./02-install-kuberay.sh"
echo "=============================================="
