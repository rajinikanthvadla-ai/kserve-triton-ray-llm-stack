#!/bin/bash
# ==============================================================================
# Helm uninstall KubeRay operator (optional; removes controller from kuberay-system)
# ==============================================================================
set -e

OPERATOR_NS="kuberay-system"

echo "=============================================="
echo "  Uninstall KubeRay operator"
echo "=============================================="
read -p "  Type 'yes' to helm uninstall: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "  Cancelled."
  exit 0
fi

helm uninstall kuberay-operator -n "$OPERATOR_NS" 2>/dev/null || true
kubectl delete namespace "$OPERATOR_NS" --ignore-not-found 2>/dev/null || true

echo "  ✅ Operator removed (CRDs may remain on cluster — normal)."
echo "=============================================="
