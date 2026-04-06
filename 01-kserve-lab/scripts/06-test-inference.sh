#!/bin/bash
# ==============================================================================
# STEP 6: Test ALL Models - Send Inference Requests!
# ==============================================================================
# What:  Tests all 3 deployed models:
#          1. sklearn-iris         (SKLearn model)
#          2. xgboost-iris         (XGBoost model)
#          3. sklearn-iris-canary  (Canary traffic split)
# How:   Uses kubectl port-forward to reach each model service directly
# Time:  ~1 minute
# ==============================================================================

set -e

echo "=============================================="
echo "  Step 6: Testing All Models"
echo "=============================================="
echo ""

# ---------- Start port-forwards to all 3 models ----------
echo "🔌 Setting up port-forwards to model services..."
echo ""

# Kill any existing port-forwards
pkill -f "port-forward.*kserve-demo" 2>/dev/null || true
sleep 1

# Port-forward each model to a different local port:
#   localhost:8081 → sklearn-iris
#   localhost:8082 → xgboost-iris
#   localhost:8083 → sklearn-iris-canary
kubectl port-forward svc/sklearn-iris-predictor -n kserve-demo 8081:80 &
PF1=$!
kubectl port-forward svc/xgboost-iris-predictor -n kserve-demo 8082:80 &
PF2=$!
kubectl port-forward svc/sklearn-iris-canary-predictor -n kserve-demo 8083:80 &
PF3=$!

sleep 3
echo "  sklearn-iris        → http://localhost:8081"
echo "  xgboost-iris        → http://localhost:8082"
echo "  sklearn-iris-canary → http://localhost:8083"
echo ""

# ==========================================
# TEST 1: SKLearn Iris Model
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST 1: SKLearn Iris Model"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Sending: [6.8, 2.8, 4.8, 1.4] and [6.0, 3.4, 4.5, 1.6]"
echo ""

RESPONSE=$(curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[6.8, 2.8, 4.8, 1.4], [6.0, 3.4, 4.5, 1.6]]}')

echo "  Response:"
echo "  $RESPONSE" | jq '.' 2>/dev/null || echo "  $RESPONSE"
echo ""

# ==========================================
# TEST 2: XGBoost Iris Model
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST 2: XGBoost Iris Model"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Sending same data to XGBoost model..."
echo ""

RESPONSE=$(curl -s http://localhost:8082/v1/models/xgboost-iris:predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[6.8, 2.8, 4.8, 1.4], [6.0, 3.4, 4.5, 1.6]]}')

echo "  Response:"
echo "  $RESPONSE" | jq '.' 2>/dev/null || echo "  $RESPONSE"
echo ""

# ==========================================
# TEST 3: Side-by-Side Comparison
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST 3: Side-by-Side — SKLearn vs XGBoost"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Setosa sample
echo "  🌸 Setosa sample: [5.1, 3.5, 1.4, 0.2]"
SK_RESP=$(curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}')
XG_RESP=$(curl -s http://localhost:8082/v1/models/xgboost-iris:predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}')
echo "     SKLearn says: $SK_RESP"
echo "     XGBoost says: $XG_RESP"
echo ""

# Versicolor sample
echo "  🌺 Versicolor sample: [6.7, 3.0, 5.0, 1.7]"
SK_RESP=$(curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[6.7, 3.0, 5.0, 1.7]]}')
XG_RESP=$(curl -s http://localhost:8082/v1/models/xgboost-iris:predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[6.7, 3.0, 5.0, 1.7]]}')
echo "     SKLearn says: $SK_RESP"
echo "     XGBoost says: $XG_RESP"
echo ""

# Virginica sample
echo "  🌷 Virginica sample: [7.7, 3.8, 6.7, 2.2]"
SK_RESP=$(curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[7.7, 3.8, 6.7, 2.2]]}')
XG_RESP=$(curl -s http://localhost:8082/v1/models/xgboost-iris:predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[7.7, 3.8, 6.7, 2.2]]}')
echo "     SKLearn says: $SK_RESP"
echo "     XGBoost says: $XG_RESP"
echo ""

# ==========================================
# TEST 4: Canary Model
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST 4: Canary Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Sending 5 requests to the canary endpoint..."
echo ""

for i in $(seq 1 5); do
    RESP=$(curl -s http://localhost:8083/v1/models/sklearn-iris-canary:predict \
        -H "Content-Type: application/json" \
        -d '{"instances": [[6.8, 2.8, 4.8, 1.4]]}')
    echo "  Request $i → $RESP"
done
echo ""

# ==========================================
# TEST 5: Batch Prediction
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST 5: Batch Prediction (5 samples at once)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

RESPONSE=$(curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
    -H "Content-Type: application/json" \
    -d '{
      "instances": [
        [5.1, 3.5, 1.4, 0.2],
        [6.7, 3.0, 5.0, 1.7],
        [7.7, 3.8, 6.7, 2.2],
        [4.9, 3.1, 1.5, 0.1],
        [6.3, 2.5, 4.9, 1.5]
      ]
    }')

echo "  Response:"
echo "  $RESPONSE" | jq '.' 2>/dev/null || echo "  $RESPONSE"
echo ""
echo "  Expected: [0, 1, 2, 0, 1]"
echo "  Meaning:  Setosa, Versicolor, Virginica, Setosa, Versicolor"
echo ""

# ==========================================
# TEST 6: Health Checks
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST 6: Health Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SK_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/v1/models/sklearn-iris)
echo "  sklearn-iris        → HTTP $SK_HEALTH $([ "$SK_HEALTH" = "200" ] && echo '✅' || echo '❌')"

XG_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8082/v1/models/xgboost-iris)
echo "  xgboost-iris        → HTTP $XG_HEALTH $([ "$XG_HEALTH" = "200" ] && echo '✅' || echo '❌')"

CA_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8083/v1/models/sklearn-iris-canary)
echo "  sklearn-iris-canary → HTTP $CA_HEALTH $([ "$CA_HEALTH" = "200" ] && echo '✅' || echo '❌')"

echo ""

# ---------- Cleanup port-forwards ----------
kill $PF1 $PF2 $PF3 2>/dev/null || true

echo "=============================================="
echo "  🎉 All Tests Complete!"
echo ""
echo "  Class Labels:"
echo "    0 = 🌸 Setosa"
echo "    1 = 🌺 Versicolor"
echo "    2 = 🌷 Virginica"
echo ""
echo "  What we demonstrated:"
echo "    ✅ Two ML frameworks (SKLearn + XGBoost)"
echo "    ✅ Same input → compare predictions side by side"
echo "    ✅ Canary deployment"
echo "    ✅ Batch prediction (multiple samples)"
echo "    ✅ Health check endpoints"
echo "=============================================="
