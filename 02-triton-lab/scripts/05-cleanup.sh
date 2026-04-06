#!/bin/bash
# ==============================================================================
# STEP 5: Cleanup Lab 2
# ==============================================================================
# What:  Removes Triton models, S3 bucket, and credentials
# Note:  Does NOT delete the EKS cluster (shared with Lab 1)
#        Run 01-kserve-lab/scripts/07-cleanup.sh to delete the cluster
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$SCRIPT_DIR/.."

# Load config
if [ -f "$LAB_DIR/.lab-config" ]; then
    source "$LAB_DIR/.lab-config"
else
    NAMESPACE="triton-demo"
    BUCKET_NAME=""
fi

echo "=============================================="
echo "  Step 5: Cleanup Lab 2"
echo "=============================================="
echo ""

# ---------- Kill port-forwards ----------
echo "🗑️  Killing port-forwards..."
pkill -f "port-forward.*triton" 2>/dev/null || true

# ---------- Delete InferenceServices ----------
echo "🗑️  Deleting Triton InferenceServices..."
kubectl delete inferenceservice --all -n "$NAMESPACE" 2>/dev/null || true

# ---------- Delete namespace ----------
echo "🗑️  Deleting namespace $NAMESPACE..."
kubectl delete namespace "$NAMESPACE" 2>/dev/null || true

# ---------- Delete S3 bucket ----------
if [ -n "$BUCKET_NAME" ]; then
    echo "🗑️  Deleting S3 bucket $BUCKET_NAME..."
    aws s3 rb "s3://$BUCKET_NAME" --force 2>/dev/null || true
fi

# ---------- Clean local model files ----------
echo "🗑️  Cleaning local model files..."
rm -rf "$LAB_DIR/models/model-repo" 2>/dev/null || true
rm -f "$LAB_DIR/.lab-config" 2>/dev/null || true

echo ""
echo "=============================================="
echo "  ✅ Lab 2 cleaned up!"
echo ""
echo "  Deleted:"
echo "    ✅ Triton InferenceServices"
echo "    ✅ K8s namespace ($NAMESPACE)"
echo "    ✅ S3 bucket ($BUCKET_NAME)"
echo "    ✅ Local model files"
echo ""
echo "  NOT deleted (still running):"
echo "    ⚡ EKS cluster"
echo "    ⚡ KServe, Istio, cert-manager"
echo ""
echo "  To delete the cluster:"
echo "    cd ../01-kserve-lab/scripts && ./07-cleanup.sh"
echo "=============================================="
