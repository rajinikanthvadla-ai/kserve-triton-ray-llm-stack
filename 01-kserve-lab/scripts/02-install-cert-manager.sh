#!/bin/bash
# ==============================================================================
# STEP 2: Install cert-manager (via Helm)
# ==============================================================================
# What:  Installs cert-manager into the cluster
# Why:   KServe needs cert-manager to manage TLS certificates
#        (webhooks use certs to validate requests)
# Time:  ~2-3 minutes
#
# Think of cert-manager as the "security guard" that issues
# and renews SSL certificates automatically inside Kubernetes.
# ==============================================================================

set -e

echo "=============================================="
echo "  Step 2: Installing cert-manager"
echo "=============================================="
echo ""

# ---------- Add the Jetstack Helm repo ----------
echo "📦 Adding Jetstack Helm repository..."
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update
echo ""

# ---------- Create namespace ----------
echo "📁 Creating cert-manager namespace..."
kubectl create namespace cert-manager 2>/dev/null || echo "   (namespace already exists, that's fine)"
echo ""

# ---------- Install cert-manager ----------
echo "🔧 Installing cert-manager v1.14.5 via Helm..."
echo "   (This installs CRDs + controller + webhook)"
echo ""

helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --version v1.14.5 \
    --set installCRDs=true \
    --set resources.requests.cpu=50m \
    --set resources.requests.memory=64Mi \
    --wait \
    --timeout 5m

echo ""

# ---------- Verify ----------
echo "Verifying cert-manager pods..."
kubectl get pods -n cert-manager
echo ""

# Wait for all pods to be ready
echo "Waiting for cert-manager to be fully ready..."
kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=120s
echo ""

echo "=============================================="
echo "  ✅ cert-manager installed!"
echo "  Next step: ./03-install-istio.sh"
echo "=============================================="
