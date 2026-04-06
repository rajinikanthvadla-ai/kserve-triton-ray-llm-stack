#!/bin/bash
# ==============================================================================
# STEP 4: Install KServe (via kubectl apply from official GitHub releases)
# ==============================================================================
# What:  Installs KServe - the ML model serving framework
# Why:   This is THE main thing! KServe lets you deploy ML models
#        as production-ready HTTP endpoints with:
#          - Auto-scaling (even scale to zero!)
#          - Canary deployments (A/B testing models)
#          - Request batching
#          - Multi-framework support (sklearn, tensorflow, pytorch, etc.)
# Time:  ~3-5 minutes
#
# Note:  KServe's Helm repo is no longer maintained.
#        The official install method is kubectl apply from GitHub releases.
#        See: https://kserve.github.io/website/latest/admin/serverless/serverless/
#
# After this step, your cluster can serve ML models!
# ==============================================================================

set -e

KSERVE_VERSION="v0.14.1"

echo "=============================================="
echo "  Step 4: Installing KServe $KSERVE_VERSION"
echo "=============================================="
echo ""

# ==========================================
# Part A: Install KServe CRDs + Controller
# ==========================================
echo "🔧 [1/3] Installing KServe (CRDs + Controller)..."
echo "   Downloading from: github.com/kserve/kserve/releases/$KSERVE_VERSION"
echo ""

# --server-side --force-conflicts is REQUIRED because:
#   1. The InferenceService CRD is too large for regular kubectl apply
#      (annotation exceeds the 262144 bytes limit)
#   2. --force-conflicts avoids field ownership errors on re-runs
kubectl apply --server-side --force-conflicts \
    -f "https://github.com/kserve/kserve/releases/download/${KSERVE_VERSION}/kserve.yaml"

echo ""
echo "   ✅ KServe CRDs + Controller applied"
echo ""

# ==========================================
# Part B: Install KServe Built-in Serving Runtimes
# ==========================================
echo "🔧 [2/3] Installing KServe built-in serving runtimes..."
echo "   (This adds support for sklearn, xgboost, tensorflow, pytorch, etc.)"
echo ""

kubectl apply --server-side --force-conflicts \
    -f "https://github.com/kserve/kserve/releases/download/${KSERVE_VERSION}/kserve-cluster-resources.yaml"

echo ""
echo "   ✅ KServe runtimes installed"
echo ""

# ==========================================
# Part C: Switch to RawDeployment mode
# ==========================================
# KServe defaults to "Serverless" mode which requires Knative Serving.
# We use "RawDeployment" mode instead — it works with just Istio,
# uses plain Kubernetes Deployments, and is lighter for our 2-node cluster.
echo "🔧 [3/3] Switching to RawDeployment mode (no Knative needed)..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl patch configmap inferenceservice-config -n kserve \
    --type=merge \
    --patch-file "$SCRIPT_DIR/../manifests/kserve-patch.json"

echo "   ✅ RawDeployment mode enabled"
echo ""

# Restart controller to pick up the config change
echo "   Restarting KServe controller..."
kubectl rollout restart deployment kserve-controller-manager -n kserve
kubectl rollout status deployment kserve-controller-manager -n kserve --timeout=60s
echo ""

# ---------- Wait for KServe controller to be ready ----------
echo "Waiting for KServe controller to be ready..."
kubectl wait --for=condition=Ready pods --all -n kserve --timeout=180s 2>/dev/null || \
  echo "   (Some pods still starting — give it a minute)"
echo ""

# ---------- Verify ----------
echo "Verifying KServe pods..."
kubectl get pods -n kserve
echo ""

# ---------- Check CRDs are registered ----------
echo "Checking KServe CRDs..."
kubectl get crd | grep serving.kserve.io || echo "   (CRDs still registering...)"
echo ""

# ---------- Check serving runtimes ----------
echo "Checking available serving runtimes..."
kubectl get clusterservingruntimes 2>/dev/null || \
  kubectl get servingruntimes --all-namespaces 2>/dev/null || \
  echo "   (Runtimes still initializing...)"
echo ""

echo "=============================================="
echo "  ✅ KServe $KSERVE_VERSION installed!"
echo ""
echo "  Your cluster now has:"
echo "    ✅ cert-manager  (TLS certificates)"
echo "    ✅ Istio         (networking & gateway)"
echo "    ✅ KServe        (ML model serving)"
echo ""
echo "  Next step: ./05-deploy-model.sh"
echo "=============================================="
