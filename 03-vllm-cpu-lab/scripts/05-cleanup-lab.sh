#!/bin/bash
# ==============================================================================
# STEP 5: Remove vLLM workloads (namespace) — keeps the EKS cluster
# ==============================================================================

set -e

echo "=============================================="
echo "  Step 5: Delete vLLM namespace (keep cluster)"
echo "=============================================="
echo ""

kubectl delete namespace vllm-cpu-lab --ignore-not-found

echo ""
echo "=============================================="
echo "  ✅ Namespace vllm-cpu-lab removed"
echo "  To delete the whole cluster and stop AWS charges: ./06-delete-eks-cluster.sh"
echo "=============================================="
