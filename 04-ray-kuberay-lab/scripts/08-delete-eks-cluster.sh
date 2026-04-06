#!/bin/bash
# ==============================================================================
# Delete EKS cluster ray-kuberay-lab
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

CLUSTER_NAME="ray-kuberay-lab"
YAML_REGION=$(grep -E '^\s+region:' "$MANIFESTS_DIR/eks-cluster.yaml" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'")
REGION="${RAY_LAB_REGION:-${YAML_REGION:-ap-south-1}}"

echo "=============================================="
echo "  Delete EKS: $CLUSTER_NAME ($REGION)"
echo "=============================================="
read -p "  Type 'yes' to destroy: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "  Cancelled."
  exit 0
fi

eksctl delete cluster --name "$CLUSTER_NAME" --region "$REGION" --wait
echo "=============================================="
