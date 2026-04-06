#!/bin/bash
# ==============================================================================
# STEP 0: Prerequisites — kubectl can reach the cluster
# ==============================================================================

set -e

echo "=============================================="
echo "  vLLM CPU Lab — prerequisites"
echo "=============================================="
echo ""

for cmd in kubectl curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Missing: $cmd"
    exit 1
  fi
  echo "  ✅ $cmd"
done

echo ""
echo "Cluster:"
kubectl cluster-info
echo ""
echo "Nodes:"
kubectl get nodes -o wide
echo ""
echo "=============================================="
echo "  ✅ Ready to deploy vLLM"
echo "  Next: ./02-deploy-vllm.sh"
echo "  (No cluster yet? Run ./01-create-eks-cluster.sh first.)"
echo "=============================================="
