#!/bin/bash
# ==============================================================================
# STEP 2: Deploy Models on Triton via KServe
# ==============================================================================
# What:  Deploys 2 ONNX models using Triton as the serving runtime
# Time:  ~3-5 minutes (Triton image is ~1GB on first pull)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$SCRIPT_DIR/.."

source "$LAB_DIR/.lab-config"

echo "=============================================="
echo "  Step 2: Deploying Models on Triton"
echo "=============================================="
echo ""
echo "  Namespace: $NAMESPACE"
echo "  S3 Bucket: $BUCKET_NAME"
echo ""

# ---- Clean up Lab 1 models to free RAM ----
echo "[0] Freeing RAM -- removing Lab 1 models (if any)..."
kubectl delete inferenceservice --all -n kserve-demo 2>/dev/null || true
echo "   Done"
echo ""

# ---- MODEL 1: Iris ONNX on Triton ----
echo "[1/2] Deploying Iris ONNX on Triton..."

# storageUri points to triton-repo/iris/ which contains iris-onnx/ directory
# Triton sees /mnt/models/iris-onnx/ as a model
kubectl apply -f - <<EOF
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: iris-triton
  namespace: $NAMESPACE
spec:
  predictor:
    serviceAccountName: triton-sa
    model:
      modelFormat:
        name: onnx
      runtime: kserve-tritonserver
      storageUri: "s3://$BUCKET_NAME/triton-repo/iris"
      resources:
        requests:
          cpu: "200m"
          memory: "512Mi"
        limits:
          cpu: "1"
          memory: "1Gi"
EOF

echo "   Applied iris-triton"
echo ""

# ---- MODEL 2: Sentiment ONNX on Triton ----
echo "[2/2] Deploying Sentiment ONNX on Triton..."

kubectl apply -f - <<EOF
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: sentiment-triton
  namespace: $NAMESPACE
spec:
  predictor:
    serviceAccountName: triton-sa
    model:
      modelFormat:
        name: onnx
      runtime: kserve-tritonserver
      storageUri: "s3://$BUCKET_NAME/triton-repo/sentiment"
      resources:
        requests:
          cpu: "500m"
          memory: "1Gi"
        limits:
          cpu: "2"
          memory: "2Gi"
EOF

echo "   Applied sentiment-triton"
echo ""

# ---- Wait for models ----
echo "Waiting for models to become ready..."
echo "   (Triton image is ~1GB, first pull takes a few minutes)"
echo ""

wait_for_model() {
    local model_name=$1
    local max_wait=600
    local elapsed=0
    local interval=15

    while true; do
        STATUS=$(kubectl get inferenceservice "$model_name" -n "$NAMESPACE" \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

        if [ "$STATUS" = "True" ]; then
            echo "   OK $model_name -> READY"
            return 0
        fi

        if [ "$elapsed" -ge "$max_wait" ]; then
            echo "   WARN $model_name -> TIMED OUT"
            kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -5
            return 1
        fi

        echo "   ... $model_name -> $STATUS (${elapsed}s/${max_wait}s)"
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
}

wait_for_model "iris-triton" || true
wait_for_model "sentiment-triton" || true
echo ""

# ---- Show results ----
echo "=============================================="
echo "  Deployed Models"
echo "=============================================="
echo ""
kubectl get inferenceservice -n "$NAMESPACE"
echo ""

echo "Pods:"
kubectl get pods -n "$NAMESPACE"
echo ""

echo "=============================================="
echo "  Triton models deployed!"
echo ""
echo "  Test with:"
echo "    kubectl port-forward svc/iris-triton-predictor -n $NAMESPACE 8084:80 &"
echo "    kubectl port-forward svc/sentiment-triton-predictor -n $NAMESPACE 8085:80 &"
echo ""
echo "  Next step: ./03-test-inference.sh"
echo "=============================================="
