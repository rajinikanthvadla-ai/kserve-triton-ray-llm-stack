#!/bin/bash
# ==============================================================================
# STEP 1: Upload Models to S3 + Setup K8s Credentials
# ==============================================================================
# What:  1. Creates an S3 bucket for model storage
#        2. Uploads ONNX models to S3 (nested structure for Triton)
#        3. Creates K8s Secret with AWS credentials
#        4. Creates a ServiceAccount for KServe S3 access
# Time:  ~1-2 minutes
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$SCRIPT_DIR/.."
MODELS_DIR="$LAB_DIR/models"
MODEL_REPO="$MODELS_DIR/model-repo"

# Auto-detect region from cluster
REGION=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | grep -oP '(?<=\.)[a-z]+-[a-z]+-[0-9]+(?=\.)' || echo "ap-south-1")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="kserve-triton-lab-${ACCOUNT_ID}"
NAMESPACE="triton-demo"

echo "=============================================="
echo "  Step 1: S3 Setup + K8s Credentials"
echo "=============================================="
echo ""
echo "  Region:  $REGION"
echo "  Bucket:  $BUCKET_NAME"
echo "  Account: $ACCOUNT_ID"
echo ""

# ---- Part A: Create S3 Bucket ----
echo "[1/4] Creating S3 bucket..."

if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "   Bucket already exists, skipping creation"
else
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    echo "   Bucket created: s3://$BUCKET_NAME"
fi
echo ""

# ---- Part B: Upload models to S3 ----
# IMPORTANT: Triton needs nested structure:
#   /mnt/models/MODEL_NAME/1/model.onnx
# So we upload as: s3://bucket/triton-repo/iris/iris-onnx/1/model.onnx
# KServe downloads "triton-repo/iris/*" -> /mnt/models/iris-onnx/1/model.onnx

echo "[2/4] Uploading models to S3..."
echo ""

# Clean old uploads first
aws s3 rm "s3://$BUCKET_NAME/triton-repo/" --recursive --quiet 2>/dev/null || true

echo "   Uploading iris-onnx (no config.pbtxt)..."
aws s3 sync "$MODEL_REPO/iris-onnx" "s3://$BUCKET_NAME/triton-repo/iris/iris-onnx" \
    --quiet --exclude "config.pbtxt"
echo "   -> s3://$BUCKET_NAME/triton-repo/iris/iris-onnx/"

echo "   Uploading sentiment-onnx (no config.pbtxt)..."
aws s3 sync "$MODEL_REPO/sentiment-onnx" "s3://$BUCKET_NAME/triton-repo/sentiment/sentiment-onnx" \
    --quiet --exclude "config.pbtxt"
echo "   -> s3://$BUCKET_NAME/triton-repo/sentiment/sentiment-onnx/"
echo ""

echo "   Verifying S3 contents..."
aws s3 ls "s3://$BUCKET_NAME/triton-repo/" --recursive --human-readable
echo ""

# ---- Part C: Create K8s namespace + credentials ----
echo "[3/4] Creating K8s namespace and credentials..."

kubectl create namespace "$NAMESPACE" 2>/dev/null || echo "   (namespace already exists)"
kubectl label namespace "$NAMESPACE" istio-injection=enabled --overwrite 2>/dev/null || true

# Get AWS credentials
AWS_ACCESS_KEY=$(aws configure get aws_access_key_id)
AWS_SECRET_KEY=$(aws configure get aws_secret_access_key)

if [ -z "$AWS_ACCESS_KEY" ] || [ -z "$AWS_SECRET_KEY" ]; then
    echo "   ERROR: Could not read AWS credentials"
    echo "   Run: aws configure"
    exit 1
fi

# Create secret (delete first if exists)
kubectl delete secret s3-credentials -n "$NAMESPACE" 2>/dev/null || true

kubectl create secret generic s3-credentials \
    -n "$NAMESPACE" \
    --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_KEY"

# FIX: Use REGIONAL S3 endpoint (not global s3.amazonaws.com)
kubectl annotate secret s3-credentials -n "$NAMESPACE" \
    serving.kserve.io/s3-endpoint="s3.${REGION}.amazonaws.com" \
    serving.kserve.io/s3-usehttps="1" \
    serving.kserve.io/s3-region="$REGION" \
    --overwrite

echo "   Secret 's3-credentials' created with regional endpoint"
echo ""

# ---- Part D: Create ServiceAccount ----
echo "[4/4] Creating ServiceAccount..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: triton-sa
  namespace: $NAMESPACE
secrets:
  - name: s3-credentials
EOF

echo "   ServiceAccount 'triton-sa' created"
echo ""

# Save config for other scripts
echo "BUCKET_NAME=$BUCKET_NAME" > "$LAB_DIR/.lab-config"
echo "REGION=$REGION" >> "$LAB_DIR/.lab-config"
echo "NAMESPACE=$NAMESPACE" >> "$LAB_DIR/.lab-config"

echo "=============================================="
echo "  S3 + Credentials ready!"
echo ""
echo "  S3 models:"
echo "    s3://$BUCKET_NAME/triton-repo/iris/"
echo "    s3://$BUCKET_NAME/triton-repo/sentiment/"
echo ""
echo "  K8s resources:"
echo "    Namespace:      $NAMESPACE"
echo "    Secret:         s3-credentials (endpoint: s3.$REGION.amazonaws.com)"
echo "    ServiceAccount: triton-sa"
echo ""
echo "  Next step: ./02-deploy-triton-models.sh"
echo "=============================================="
