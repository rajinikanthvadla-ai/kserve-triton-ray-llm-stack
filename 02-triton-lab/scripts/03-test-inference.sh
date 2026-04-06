#!/bin/bash
# ==============================================================================
# STEP 3: Test Triton Models
# ==============================================================================
# What:  Tests both models:
#          1. Iris on Triton — curl with numbers (v2 protocol)
#          2. Sentiment on Triton — Python script with tokenization
# Time:  ~1 minute
#
# Triton uses the V2 Inference Protocol (KServe predict v2):
#   POST /v2/models/{model_name}/infer
#   This is different from v1 used in Lab 1!
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$SCRIPT_DIR/.."

source "$LAB_DIR/.lab-config"

echo "=============================================="
echo "  Step 3: Testing Triton Models"
echo "=============================================="
echo ""

# ---------- Start port-forwards ----------
echo "🔌 Setting up port-forwards..."
pkill -f "port-forward.*triton" 2>/dev/null || true
sleep 1

kubectl port-forward svc/iris-triton-predictor -n "$NAMESPACE" 8084:80 &
PF1=$!
kubectl port-forward svc/sentiment-triton-predictor -n "$NAMESPACE" 8085:80 &
PF2=$!
sleep 4

echo "  iris-triton      → http://localhost:8084"
echo "  sentiment-triton → http://localhost:8085"
echo ""

# ==========================================
# TEST 1: Iris on Triton (V2 Protocol)
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST 1: Iris on Triton (ONNX) — V2 Inference Protocol"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Input: [6.8, 2.8, 4.8, 1.4] (sepal_l, sepal_w, petal_l, petal_w)"
echo ""
echo "  Using Triton V2 protocol: POST /v2/models/iris-onnx/infer"
echo ""

RESPONSE=$(curl -s http://localhost:8084/v2/models/iris-onnx/infer \
    -H "Content-Type: application/json" \
    -d '{
        "inputs": [
            {
                "name": "float_input",
                "shape": [1, 4],
                "datatype": "FP32",
                "data": [6.8, 2.8, 4.8, 1.4]
            }
        ]
    }')

echo "  Response:"
echo "  $RESPONSE" | jq '.' 2>/dev/null || echo "  $RESPONSE"
echo ""

# ---- Also test with batch (3 flowers at once) ----
echo "  Batch prediction (3 flowers):"
echo ""

RESPONSE=$(curl -s http://localhost:8084/v2/models/iris-onnx/infer \
    -H "Content-Type: application/json" \
    -d '{
        "inputs": [
            {
                "name": "float_input",
                "shape": [3, 4],
                "datatype": "FP32",
                "data": [
                    5.1, 3.5, 1.4, 0.2,
                    6.7, 3.0, 5.0, 1.7,
                    7.7, 3.8, 6.7, 2.2
                ]
            }
        ]
    }')

echo "  $RESPONSE" | jq '.' 2>/dev/null || echo "  $RESPONSE"
echo ""
echo "  Expected: Setosa(0), Versicolor/Virginica(1/2), Virginica(2)"
echo ""

# ==========================================
# TEST 2: Triton Model Info
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST 2: Triton Model Metadata (V2 API)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "  --- Iris model metadata ---"
curl -s http://localhost:8084/v2/models/iris-onnx | jq '.' 2>/dev/null
echo ""

echo "  --- Sentiment model metadata ---"
curl -s http://localhost:8085/v2/models/sentiment-onnx | jq '.' 2>/dev/null
echo ""

# ==========================================
# TEST 3: Sentiment Analysis (Python script)
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST 3: Sentiment Analysis (Text → Triton → Prediction)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Running Python test script..."
echo "  (Tokenizes text locally, sends tokens to Triton)"
echo ""

cd "$LAB_DIR/models"
python test-sentiment.py
cd "$SCRIPT_DIR"
echo ""

# ==========================================
# TEST 4: Health checks
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST 4: Health Checks (V2 API)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

IRIS_READY=$(curl -s http://localhost:8084/v2/models/iris-onnx/ready)
echo "  iris-triton      → Ready: $IRIS_READY"

SENT_READY=$(curl -s http://localhost:8085/v2/models/sentiment-onnx/ready)
echo "  sentiment-triton → Ready: $SENT_READY"

IRIS_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8084/v2/health/ready)
echo "  Triton server #1 → HTTP $IRIS_HEALTH $([ "$IRIS_HEALTH" = "200" ] && echo '✅' || echo '❌')"

SENT_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8085/v2/health/ready)
echo "  Triton server #2 → HTTP $SENT_HEALTH $([ "$SENT_HEALTH" = "200" ] && echo '✅' || echo '❌')"

echo ""

# Cleanup
kill $PF1 $PF2 2>/dev/null || true

echo "=============================================="
echo "  🎉 All Tests Complete!"
echo ""
echo "  What we demonstrated:"
echo "    ✅ Iris ONNX model on Triton (numeric input)"
echo "    ✅ Sentiment ONNX model on Triton (text input)"
echo "    ✅ V2 Inference Protocol (different from Lab 1's V1)"
echo "    ✅ Triton model metadata API"
echo "    ✅ Dynamic batching (3 flowers in one request)"
echo "    ✅ Health check endpoints"
echo ""
echo "  Next: ./04-triton-features.sh"
echo "=============================================="
