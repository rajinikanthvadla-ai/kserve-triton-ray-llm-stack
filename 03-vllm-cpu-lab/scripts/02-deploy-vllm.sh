#!/bin/bash
# ==============================================================================
# STEP 2: Deploy vLLM (CPU OpenAI server) on EKS
# ==============================================================================
# What: Namespace + Deployment + Service
# Next: Run ./03-watch-vllm-live.sh to stream image pull + model load in real time.
#
# Hugging Face token: NOT needed for default public model (SmolLM2-135M-Instruct).
# If you use a gated/private model, create the secret BEFORE this step — see README
# section "Hugging Face token: do you need it?"
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

echo "=============================================="
echo "  Step 2: Deploy vLLM CPU"
echo "=============================================="
echo ""

kubectl apply -f "$MANIFESTS_DIR/namespace.yaml"
# Leftover from older lab drafts (ConfigMap-based chat template); safe if missing
kubectl delete configmap vllm-chat-template -n vllm-cpu-lab --ignore-not-found 2>/dev/null || true
kubectl apply -f "$MANIFESTS_DIR/vllm-cpu.yaml"

echo ""
echo "  Manifests applied."
echo "  The pod will pull a large image and download the model — this takes time."
echo ""
echo "  👉 For real-time startup logs, run:  ./03-watch-vllm-live.sh"
echo "  👉 When the server is ready (or after logs show Uvicorn listening), run:  ./04-test-chat.sh"
echo ""
echo "=============================================="
