#!/bin/bash
# ==============================================================================
# STEP 3: Real-time flow — watch vLLM come up (pod + logs)
# ==============================================================================
# What: Prints pod phase until Running, recent events, then streams container logs.
#       You should see: image pull → Hugging Face download → model load → Uvicorn ready.
# Stop: Press Ctrl+C when you are satisfied (server usually ready when Uvicorn says listening).
# ==============================================================================

set -e

NAMESPACE="vllm-cpu-lab"
DEPLOY="vllm-opt125m-cpu"
LABEL="app=vllm-opt125m-cpu"

echo "=============================================="
echo "  Step 3: Live vLLM startup (real-time)"
echo "=============================================="
echo ""
echo "Tip: In a second terminal you can run:"
echo "     kubectl get pods -n $NAMESPACE -w"
echo ""

echo "[Phase] Waiting for pod to exist..."
for _ in $(seq 1 120); do
  if kubectl get pods -n "$NAMESPACE" -l "$LABEL" -o name 2>/dev/null | grep -q pod/; then
    break
  fi
  kubectl get pods -n "$NAMESPACE" 2>/dev/null || true
  sleep 2
done

echo ""
echo "[Phase] Pod status until Running (Ctrl+C to skip ahead to logs)..."
while true; do
  PHASE=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Pending")
  READY=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL" -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
  echo "$(date -u +"%H:%M:%SZ")  phase=$PHASE  ready=$READY"
  if [[ "$PHASE" == "Running" ]]; then
    break
  fi
  if [[ "$PHASE" == "Failed" ]] || [[ "$PHASE" == "Unknown" ]]; then
    echo "Pod not healthy. Check: kubectl describe pod -n $NAMESPACE -l $LABEL"
    exit 1
  fi
  sleep 4
done

echo ""
echo "[Events] Last 15 namespace events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp 2>/dev/null | tail -15 || true

echo ""
echo "[Logs] Streaming vLLM container logs (Ctrl+C to stop)..."
echo "       Ready when you see Uvicorn / Application startup complete / listening on 0.0.0.0:8000"
echo ""

kubectl logs -f "deployment/$DEPLOY" -n "$NAMESPACE" --tail=40
