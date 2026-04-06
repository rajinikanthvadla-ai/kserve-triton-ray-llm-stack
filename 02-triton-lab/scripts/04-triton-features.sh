#!/bin/bash
# ==============================================================================
# STEP 4: Triton-Specific Features Demo
# ==============================================================================
# What:  Shows features UNIQUE to Triton that sklearn-server doesn't have:
#          1. Prometheus metrics endpoint (/metrics)
#          2. Model statistics (inference count, latency)
#          3. Dynamic batching in action
#          4. V2 model repository API
# Why:   This is WHY companies choose Triton over simpler model servers
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$SCRIPT_DIR/.."
source "$LAB_DIR/.lab-config"

echo "=============================================="
echo "  Step 4: Triton-Specific Features"
echo "=============================================="
echo ""

# Start port-forwards
pkill -f "port-forward.*triton" 2>/dev/null || true
sleep 1
kubectl port-forward svc/iris-triton-predictor -n "$NAMESPACE" 8084:80 &
PF1=$!
sleep 3

# ==========================================
# FEATURE 1: Triton Server Metadata
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FEATURE 1: Triton Server Info"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  GET /v2  → Shows Triton version, extensions, ready state"
echo ""

curl -s http://localhost:8084/v2 | jq '.' 2>/dev/null
echo ""

# ==========================================
# FEATURE 2: Model Metadata (input/output shapes)
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FEATURE 2: Model Metadata (shows input/output spec)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  GET /v2/models/iris-onnx"
echo "  → Shows exact input names, shapes, datatypes"
echo "  → Developers use this to know HOW to call the model"
echo ""

curl -s http://localhost:8084/v2/models/iris-onnx | jq '.' 2>/dev/null
echo ""

echo "  Key insight:"
echo "    This metadata endpoint replaces documentation!"
echo "    Any developer can query it to learn the model's API."
echo ""

# ==========================================
# FEATURE 3: Dynamic Batching Demo
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FEATURE 3: Dynamic Batching"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Triton can batch multiple individual requests into ONE"
echo "  inference call. This dramatically improves GPU throughput."
echo ""
echo "  Our config.pbtxt has:"
echo "    max_batch_size: 8"
echo "    dynamic_batching { max_queue_delay_microseconds: 100 }"
echo ""
echo "  Sending 5 rapid requests in parallel..."
echo ""

# Fire 5 requests in parallel
for i in $(seq 1 5); do
    curl -s http://localhost:8084/v2/models/iris-onnx/infer \
        -H "Content-Type: application/json" \
        -d "{\"inputs\": [{\"name\": \"float_input\", \"shape\": [1,4], \"datatype\": \"FP32\", \"data\": [$i.0, 3.0, 4.5, 1.5]}]}" &
done
wait

echo ""
echo "  ✅ All 5 completed. Triton may have batched these together!"
echo "  (Check metrics below for batch statistics)"
echo ""

# ==========================================
# FEATURE 4: Prometheus Metrics
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FEATURE 4: Prometheus Metrics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  GET /metrics  → Prometheus-format metrics"
echo "  In production, Grafana scrapes these for dashboards."
echo ""

# Get metrics and show the most interesting ones
METRICS=$(curl -s http://localhost:8084/metrics 2>/dev/null || echo "Metrics not available on this port")

if echo "$METRICS" | grep -q "nv_inference_count"; then
    echo "  📊 Inference count:"
    echo "$METRICS" | grep "nv_inference_count" | head -5
    echo ""

    echo "  📊 Inference latency (microseconds):"
    echo "$METRICS" | grep "nv_inference_compute_infer_duration_us" | head -5
    echo ""

    echo "  📊 Queue time (batching wait):"
    echo "$METRICS" | grep "nv_inference_queue_duration_us" | head -5
    echo ""
else
    echo "  Metrics endpoint may be on port 8002 (Triton's default)."
    echo "  In production, you'd configure Prometheus to scrape it."
    echo ""
    echo "  Triton exposes these metrics:"
    echo "    nv_inference_count          — total predictions served"
    echo "    nv_inference_exec_count     — total batches executed"
    echo "    nv_inference_request_duration_us   — end-to-end latency"
    echo "    nv_inference_queue_duration_us     — time waiting in batch queue"
    echo "    nv_inference_compute_infer_duration_us — actual model compute time"
fi
echo ""

# ==========================================
# FEATURE 5: Model Repository API
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FEATURE 5: V2 Model Ready/Live Endpoints"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "  Server ready:"
curl -s -o /dev/null -w "  HTTP %{http_code}" http://localhost:8084/v2/health/ready
echo " $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8084/v2/health/ready | grep -q 200 && echo '✅' || echo '❌')"
echo ""

echo "  Server live:"
curl -s -o /dev/null -w "  HTTP %{http_code}" http://localhost:8084/v2/health/live
echo " $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8084/v2/health/live | grep -q 200 && echo '✅' || echo '❌')"
echo ""

echo "  Model ready (iris-onnx):"
curl -s http://localhost:8084/v2/models/iris-onnx/ready
echo ""
echo ""

# Cleanup
kill $PF1 2>/dev/null || true

echo "=============================================="
echo "  🎉 Triton Features Demo Complete!"
echo ""
echo "  Why Triton over sklearn-server?"
echo "    ✅ Dynamic batching → higher throughput"
echo "    ✅ ONNX Runtime → faster inference on CPU & GPU"
echo "    ✅ Prometheus metrics → production monitoring"
echo "    ✅ V2 protocol → industry standard API"
echo "    ✅ Model metadata → self-documenting API"
echo "    ✅ Multi-model → serve many models in one server"
echo ""
echo "  Next: ./05-cleanup.sh (when done)"
echo "=============================================="
