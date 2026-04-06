#!/bin/bash
# ==============================================================================
# Delete RayCluster + ray-lab namespace (keeps EKS + KubeRay operator)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

echo "=============================================="
echo "  Cleanup: RayCluster + namespace ray-lab"
echo "=============================================="

kubectl delete -f "$MANIFESTS_DIR/ray-cluster.yaml" --ignore-not-found
kubectl delete namespace ray-lab --ignore-not-found

echo ""
echo "  KubeRay operator still installed in kuberay-system."
echo "  Remove it: ./07-uninstall-kuberay-operator.sh"
echo "  Delete EKS:  ./08-delete-eks-cluster.sh"
echo "=============================================="
