#!/bin/bash
# ==============================================================================
# STEP 4: Wait for rollout, then call OpenAI-compatible API
# ==============================================================================
# Model id is read from GET /v1/models (must match whatever the server actually
# loaded — avoids 404 if your kubectl apply used the wrong working directory).
# ==============================================================================

set -e

NAMESPACE="vllm-cpu-lab"
SERVICE="vllm-opt125m"
DEPLOY="vllm-opt125m-cpu"
LOCAL_PORT="${LOCAL_PORT:-8000}"

echo "=============================================="
echo "  Step 4: Test OpenAI-compatible endpoints"
echo "=============================================="
echo ""

echo "Waiting for Deployment rollout (image pull + model load can take many minutes)..."
kubectl rollout status "deployment/$DEPLOY" -n "$NAMESPACE" --timeout=45m

echo ""
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" "${LOCAL_PORT}:8000" &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null || true' EXIT

echo "Port-forward pid $PF_PID — waiting for TCP..."
sleep 6

echo ""
echo "--- GET /v1/models (discover served model id) ---"
MODELS_JSON=$(curl -sS "http://127.0.0.1:${LOCAL_PORT}/v1/models")
echo "$MODELS_JSON" | jq .
MODEL=$(echo "$MODELS_JSON" | jq -r '.data[0].id // empty')
if [ -z "$MODEL" ] || [ "$MODEL" = "null" ]; then
  echo "❌ No model in /v1/models — is vLLM up?"
  exit 1
fi
echo ""
echo "👉 Using model id for requests: $MODEL"

echo ""
echo "--- POST /v1/completions ---"
curl -sS "http://127.0.0.1:${LOCAL_PORT}/v1/completions" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg m "$MODEL" \
    '{model: $m, prompt: "Say hello in one short sentence.", max_tokens: 64, temperature: 0.7}')" | jq .

echo ""
echo "--- POST /v1/chat/completions ---"
CHAT_JSON=$(curl -sS "http://127.0.0.1:${LOCAL_PORT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg m "$MODEL" \
    '{model: $m, messages: [{role: "user", content: "Say hello in one short sentence."}], max_tokens: 64, temperature: 0.7}')")
echo "$CHAT_JSON" | jq .
if echo "$CHAT_JSON" | jq -e '.error.message | test("chat template")' >/dev/null 2>&1; then
  echo ""
  echo "⚠️  Chat needs a tokenizer chat_template (Transformers v4.44+). Raw LMs like OPT fail here."
  echo "   Redeploy the latest manifest from this folder:  ./apply-manifests.sh"
  echo "   (uses SmolLM2-135M-Instruct — chat works after rollout finishes.)"
fi

echo ""
echo "=============================================="
echo "  ✅ API smoke test finished"
echo "=============================================="
