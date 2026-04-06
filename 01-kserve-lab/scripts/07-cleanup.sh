#!/bin/bash
# ==============================================================================
# STEP 7: Cleanup - Delete Everything
# ==============================================================================
# What:  Deletes the EKS cluster and all resources
# Why:   SAVE MONEY! Don't leave the cluster running.
#        The cluster costs ~$5/day even if you're not using it.
# Time:  ~10-15 minutes
#
# ⚠️  THIS DELETES EVERYTHING - cluster, nodes, all deployments
# ==============================================================================

set -e

CLUSTER_NAME="kserve-lab"
REGION="ap-south-1"
KSERVE_VERSION="v0.14.1"

echo "=============================================="
echo "  Step 7: Cleanup"
echo "=============================================="
echo ""
echo "  ⚠️  This will DELETE:"
echo "    - EKS cluster '$CLUSTER_NAME'"
echo "    - All 2 EC2 worker nodes"
echo "    - All deployed models and services"
echo "    - All associated AWS resources"
echo ""

# ---------- Ask for confirmation ----------
read -p "  Are you sure? Type 'yes' to confirm: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "  Cancelled. Nothing was deleted."
    exit 0
fi

echo ""

# ---------- Kill port-forwards ----------
echo "🗑️  Killing port-forwards..."
pkill -f "port-forward.*kserve-demo" 2>/dev/null || true

# ---------- Delete the InferenceServices ----------
echo "🗑️  Deleting InferenceServices..."
kubectl delete inferenceservice --all -n kserve-demo 2>/dev/null || true
kubectl delete namespace kserve-demo 2>/dev/null || true
echo ""

# ---------- Delete KServe (installed via kubectl apply, NOT Helm) ----------
echo "🗑️  Deleting KServe..."
kubectl delete -f "https://github.com/kserve/kserve/releases/download/${KSERVE_VERSION}/kserve-cluster-resources.yaml" 2>/dev/null || true
kubectl delete -f "https://github.com/kserve/kserve/releases/download/${KSERVE_VERSION}/kserve.yaml" 2>/dev/null || true
echo ""

# ---------- Uninstall Helm releases (Istio + cert-manager) ----------
echo "🗑️  Uninstalling Istio..."
helm uninstall istio-ingress -n istio-ingress 2>/dev/null || true
helm uninstall istiod -n istio-system 2>/dev/null || true
helm uninstall istio-base -n istio-system 2>/dev/null || true

echo "🗑️  Uninstalling cert-manager..."
helm uninstall cert-manager -n cert-manager 2>/dev/null || true
echo ""

# ---------- Delete the EKS cluster ----------
echo "🗑️  Deleting EKS cluster '$CLUSTER_NAME'..."
echo "   (This takes ~10-15 minutes)"
echo ""

eksctl delete cluster --name "$CLUSTER_NAME" --region "$REGION" --wait

echo ""
echo "=============================================="
echo "  ✅ All cleaned up!"
echo ""
echo "  Deleted:"
echo "    ✅ EKS cluster"
echo "    ✅ EC2 nodes"
echo "    ✅ Load balancers"
echo "    ✅ CloudFormation stacks"
echo ""
echo "  Your AWS bill will stop accumulating now."
echo "=============================================="
