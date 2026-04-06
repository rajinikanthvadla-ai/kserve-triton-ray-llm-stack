#!/bin/bash
# ==============================================================================
# STEP 6: Delete EKS cluster (stops ~\$0.20/hr charges)
# ==============================================================================
# What: Deletes cluster vllm-cpu-lab and worker nodes (same as eksctl create).
# Time: ~10–15 minutes
#
# Override region:  export VLLM_LAB_REGION=us-east-1
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

CLUSTER_NAME="vllm-cpu-lab"
YAML_REGION=$(grep -E '^\s+region:' "$MANIFESTS_DIR/eks-cluster.yaml" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'")
REGION="${VLLM_LAB_REGION:-${YAML_REGION:-ap-south-1}}"

echo "=============================================="
echo "  Step 6: Delete EKS cluster"
echo "=============================================="
echo ""
echo "  This will DELETE:"
echo "    - Cluster: $CLUSTER_NAME ($REGION)"
echo "    - All worker nodes and workloads in that cluster"
echo ""

read -p "  Type 'yes' to destroy the cluster: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "  Cancelled."
  exit 0
fi

echo ""
echo "Deleting cluster (this takes ~10–15 minutes)..."
eksctl delete cluster --name "$CLUSTER_NAME" --region "$REGION" --wait

echo ""
echo "=============================================="
echo "  ✅ Cluster deleted — billing for this cluster should stop."
echo "=============================================="
