#!/bin/bash
# ==============================================================================
# STEP 3: Install Istio Service Mesh (via Helm)
# ==============================================================================
# What:  Installs Istio into the cluster
# Why:   KServe uses Istio as its networking layer.
#        Istio handles:
#          - Routing HTTP requests to the right model
#          - Load balancing between model replicas
#          - The external gateway (how traffic enters the cluster)
# Time:  ~3-5 minutes
#
# We install 3 Istio components:
#   1. istio-base    → CRDs (Custom Resource Definitions)
#   2. istiod        → The control plane (the "brain")
#   3. istio-ingress → The gateway (the "front door")
# ==============================================================================

set -e

echo "=============================================="
echo "  Step 3: Installing Istio Service Mesh"
echo "=============================================="
echo ""

# ---------- Add Istio Helm repo ----------
echo "📦 Adding Istio Helm repository..."
helm repo add istio https://istio-release.storage.googleapis.com/charts 2>/dev/null || true
helm repo update
echo ""

# ---------- Create namespace ----------
echo "📁 Creating istio-system namespace..."
kubectl create namespace istio-system 2>/dev/null || echo "   (namespace already exists)"
echo ""

# ==========================================
# Part A: Install Istio Base (CRDs)
# ==========================================
echo "🔧 [1/3] Installing Istio Base (CRDs)..."
helm upgrade --install istio-base istio/base \
    --namespace istio-system \
    --set defaultRevision=default \
    --wait \
    --timeout 5m
echo "   ✅ Istio Base installed"
echo ""

# ==========================================
# Part B: Install Istiod (Control Plane)
# ==========================================
echo "🔧 [2/3] Installing Istiod (Control Plane)..."
helm upgrade --install istiod istio/istiod \
    --namespace istio-system \
    --set pilot.resources.requests.cpu=100m \
    --set pilot.resources.requests.memory=128Mi \
    --wait \
    --timeout 5m
echo "   ✅ Istiod installed"
echo ""

# ==========================================
# Part C: Install Istio Ingress Gateway
# ==========================================
echo "📁 Creating istio-ingress namespace..."
kubectl create namespace istio-ingress 2>/dev/null || echo "   (namespace already exists)"

echo "🔧 [3/3] Installing Istio Ingress Gateway..."
helm upgrade --install istio-ingress istio/gateway \
    --namespace istio-ingress \
    --set service.type=LoadBalancer \
    --set resources.requests.cpu=50m \
    --set resources.requests.memory=64Mi \
    --wait \
    --timeout 5m
echo "   ✅ Istio Ingress Gateway installed"
echo ""

# ---------- Verify ----------
echo "Verifying Istio pods..."
echo ""
echo "--- istio-system namespace ---"
kubectl get pods -n istio-system
echo ""
echo "--- istio-ingress namespace ---"
kubectl get pods -n istio-ingress
echo ""

echo "Waiting for all Istio pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n istio-system --timeout=120s
kubectl wait --for=condition=Ready pods --all -n istio-ingress --timeout=120s
echo ""

# ---------- Get the External IP ----------
echo "Getting Istio Ingress Gateway external IP..."
echo "(This is the URL you'll use to reach your models)"
echo ""
kubectl get svc -n istio-ingress
echo ""

echo "=============================================="
echo "  ✅ Istio installed!"
echo "  Next step: ./04-install-kserve.sh"
echo "=============================================="
