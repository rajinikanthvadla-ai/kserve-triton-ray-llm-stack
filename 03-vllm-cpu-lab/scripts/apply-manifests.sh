#!/bin/bash
# ==============================================================================
# Apply Kubernetes manifests using paths relative to THIS script (no cd mistakes)
# ==============================================================================
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

echo "Applying from: $MANIFESTS_DIR"
kubectl apply -f "$MANIFESTS_DIR/namespace.yaml"
kubectl delete configmap vllm-chat-template -n vllm-cpu-lab --ignore-not-found 2>/dev/null || true
kubectl apply -f "$MANIFESTS_DIR/vllm-cpu.yaml"
echo ""
echo "Rolling deployment to pick up changes..."
kubectl rollout restart deployment/vllm-opt125m-cpu -n vllm-cpu-lab
kubectl rollout status deployment/vllm-opt125m-cpu -n vllm-cpu-lab --timeout=45m
echo "✅ Done. Next: ./04-test-chat.sh"
