#!/bin/bash
# ==============================================================================
# Apply Ray manifests from correct paths (run from scripts/)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

echo "Applying from: $MANIFESTS_DIR"
kubectl apply -f "$MANIFESTS_DIR/namespace.yaml"
kubectl apply -f "$MANIFESTS_DIR/ray-cluster.yaml"
echo "Done. Wait for pods: kubectl get pods -n ray-lab -w"
echo "Or: ./03-deploy-ray-cluster.sh (includes wait)"
