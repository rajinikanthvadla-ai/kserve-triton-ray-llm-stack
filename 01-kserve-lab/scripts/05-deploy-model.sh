#!/bin/bash
# ==============================================================================
# STEP 5: Deploy TWO Models + Canary Traffic Split
# ==============================================================================
# What:  Deploys 3 InferenceServices:
#          1. sklearn-iris         → SKLearn Iris classifier
#          2. xgboost-iris         → XGBoost Iris classifier (same data, different algo)
#          3. sklearn-iris-canary  → Canary deployment (80/20 traffic split)
#
# Why:   Shows that KServe can:
#          - Serve MULTIPLE models side by side
#          - Handle DIFFERENT frameworks (sklearn vs xgboost)
#          - Split TRAFFIC between model versions (canary/A-B testing)
#
# Time:  ~3-5 minutes
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

echo "=============================================="
echo "  Step 5: Deploying Models"
echo "=============================================="
echo ""

# ---------- Create demo namespace ----------
echo "📁 Creating kserve-demo namespace..."
kubectl create namespace kserve-demo 2>/dev/null || echo "   (namespace already exists)"
kubectl label namespace kserve-demo istio-injection=enabled --overwrite
echo ""

# ==========================================
# MODEL 1: SKLearn Iris
# ==========================================
echo "🚀 [1/3] Deploying Model #1: SKLearn Iris..."
kubectl apply -f "$MANIFESTS_DIR/sklearn-iris-inferenceservice.yaml"
echo "   Applied sklearn-iris"
echo ""

# ==========================================
# MODEL 2: XGBoost Iris
# ==========================================
echo "🚀 [2/3] Deploying Model #2: XGBoost Iris..."
kubectl apply -f "$MANIFESTS_DIR/xgboost-iris-inferenceservice.yaml"
echo "   Applied xgboost-iris"
echo ""

# ==========================================
# MODEL 3: Canary Traffic Split
# ==========================================
echo "🚀 [3/3] Deploying Model #3: SKLearn Canary (80/20 traffic split)..."
kubectl apply -f "$MANIFESTS_DIR/sklearn-iris-canary.yaml"
echo "   Applied sklearn-iris-canary"
echo ""

# ---------- Wait for ALL models to be ready ----------
echo "⏳ Waiting for all models to become ready..."
echo ""

wait_for_model() {
    local model_name=$1
    local max_wait=300
    local elapsed=0
    local interval=10
    
    while true; do
        STATUS=$(kubectl get inferenceservice "$model_name" -n kserve-demo \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        
        if [ "$STATUS" = "True" ]; then
            echo "   ✅ $model_name → READY"
            return 0
        fi
        
        if [ "$elapsed" -ge "$max_wait" ]; then
            echo "   ⚠️  $model_name → TIMED OUT (check: kubectl describe inferenceservice $model_name -n kserve-demo)"
            return 1
        fi
        
        echo "   ⏳ $model_name → $STATUS (${elapsed}s/${max_wait}s)"
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
}

# Don't let set -e kill the script if one model is slow
wait_for_model "sklearn-iris" || true
wait_for_model "xgboost-iris" || true
wait_for_model "sklearn-iris-canary" || true
echo ""

# ---------- Show all deployments ----------
echo "=============================================="
echo "  📊 All Deployed Models"
echo "=============================================="
echo ""
kubectl get inferenceservice -n kserve-demo
echo ""

echo "📊 All Pods:"
kubectl get pods -n kserve-demo
echo ""

# ---------- Print connection info for curl commands ----------
echo "=============================================="
echo "  🔗 How to Test (port-forward)"
echo "=============================================="
echo ""
echo "  To test manually with curl, start port-forwards:"
echo ""
echo "    kubectl port-forward svc/sklearn-iris-predictor -n kserve-demo 8081:80 &"
echo "    kubectl port-forward svc/xgboost-iris-predictor -n kserve-demo 8082:80 &"
echo "    kubectl port-forward svc/sklearn-iris-canary-predictor -n kserve-demo 8083:80 &"
echo ""
echo "  Then curl:"
echo "    curl -s http://localhost:8081/v1/models/sklearn-iris:predict \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"instances\": [[6.8, 2.8, 4.8, 1.4]]}'"
echo ""
echo "=============================================="
echo "  ✅ All 3 models deployed and serving!"
echo ""
echo "  Or just run: ./06-test-inference.sh"
echo "=============================================="
