#!/bin/bash
# ==============================================================================
# STEP 1: Create EKS cluster (this lab only)
# ==============================================================================
# What: Minimal EKS + 2x t3.medium CPU nodes for vLLM CPU
# Cost: ~$0.20/hr — delete the cluster when done (./06-delete-eks-cluster.sh)
# Time: ~15–20 minutes
#
# Override region:  export VLLM_LAB_REGION=us-east-1
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

CLUSTER_NAME="vllm-cpu-lab"
# Region must match manifests/eks-cluster.yaml — override with VLLM_LAB_REGION if you edit the file
YAML_REGION=$(grep -E '^\s+region:' "$MANIFESTS_DIR/eks-cluster.yaml" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'")
REGION="${VLLM_LAB_REGION:-${YAML_REGION:-ap-south-1}}"

echo "=============================================="
echo "  Step 1: Creating EKS cluster (vLLM CPU lab)"
echo "=============================================="
echo ""
echo "  Cluster:    $CLUSTER_NAME"
echo "  Region:     $REGION"
echo "  Config:     $MANIFESTS_DIR/eks-cluster.yaml"
echo "  Nodes:      2x t3.medium (2 vCPU, 4 GB RAM each)"
echo "  Est. cost:  ~\$0.20/hr — run ./06-delete-eks-cluster.sh after the lab"
echo "  Est. time:  ~15–20 minutes"
echo ""

if eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null; then
  echo "⚠️  Cluster '$CLUSTER_NAME' already exists in $REGION."
  echo "   Updating kubeconfig..."
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
  echo "  ✅ kubeconfig updated. Skipping creation."
  exit 0
fi

echo "🚀 Creating cluster (eksctl)..."
echo ""

eksctl create cluster -f "$MANIFESTS_DIR/eks-cluster.yaml"

echo ""
echo "=============================================="
echo "  ✅ EKS cluster ready"
echo "=============================================="
echo ""

kubectl cluster-info
echo ""
kubectl get nodes -o wide
echo ""
echo "=============================================="
echo "  Next: ./02-deploy-vllm.sh"
echo "  Then: ./03-watch-vllm-live.sh  (real-time logs while vLLM starts)"
echo "  Then: ./04-test-chat.sh"
echo "=============================================="
