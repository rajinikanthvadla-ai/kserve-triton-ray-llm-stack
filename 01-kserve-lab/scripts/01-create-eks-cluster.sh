#!/bin/bash
# ==============================================================================
# STEP 1: Create EKS Cluster
# ==============================================================================
# What:  Creates a minimal EKS cluster with 2 CPU nodes on AWS
# Why:   We need a Kubernetes cluster to install KServe on
# Cost:  ~$0.20/hr total (~$5/day if left running)
# Time:  ~15-20 minutes (EKS takes a while to provision)
#
# What happens behind the scenes:
#   1. eksctl creates a CloudFormation stack
#   2. AWS provisions the EKS control plane (managed by AWS)
#   3. AWS launches 2x t3.medium EC2 instances as worker nodes
#   4. eksctl configures your kubectl to point to this cluster
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

CLUSTER_NAME="kserve-lab"
REGION="ap-south-1"

echo "=============================================="
echo "  Step 1: Creating EKS Cluster"
echo "=============================================="
echo ""
echo "  Cluster:    $CLUSTER_NAME"
echo "  Region:     $REGION"
echo "  Nodes:      2x t3.medium (2 vCPU, 4GB RAM each)"
echo "  Est. Cost:  ~\$0.20/hr (\$5/day)"
echo "  Est. Time:  ~15-20 minutes"
echo ""

# ---------- Check if cluster already exists ----------
if eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null; then
    echo "⚠️  Cluster '$CLUSTER_NAME' already exists!"
    echo "   Updating kubeconfig to point to existing cluster..."
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
    echo "  ✅ kubeconfig updated. Skipping cluster creation."
    exit 0
fi

# ---------- Create the cluster ----------
echo "🚀 Creating EKS cluster (grab a coffee, this takes ~15-20 min)..."
echo ""

eksctl create cluster -f "$MANIFESTS_DIR/eks-cluster.yaml"

echo ""
echo "=============================================="
echo "  ✅ EKS Cluster Created!"
echo "=============================================="
echo ""

# ---------- Verify ----------
echo "Verifying cluster access..."
echo ""

echo "Cluster info:"
kubectl cluster-info
echo ""

echo "Nodes (you should see 2):"
kubectl get nodes -o wide
echo ""

echo "=============================================="
echo "  ✅ Cluster is ready!"
echo "  Next step: ./02-install-cert-manager.sh"
echo "=============================================="
