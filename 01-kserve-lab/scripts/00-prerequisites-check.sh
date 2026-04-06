#!/bin/bash
# ==============================================================================
# STEP 0: Check Prerequisites
# ==============================================================================
# What:  Verifies all required CLI tools are installed
# Why:   Better to catch missing tools NOW than halfway through setup
# Time:  ~5 seconds
# ==============================================================================

set -e  # exit on any error

echo "=============================================="
echo "  KServe Lab - Prerequisites Check"
echo "=============================================="
echo ""

MISSING=0

# ---------- Function to check if a command exists ----------
check_tool() {
    local tool_name=$1
    local install_hint=$2
    
    if command -v "$tool_name" &> /dev/null; then
        local version
        version=$($tool_name version 2>/dev/null || $tool_name --version 2>/dev/null | head -1)
        echo "  ✅  $tool_name  → $version"
    else
        echo "  ❌  $tool_name  → NOT FOUND"
        echo "      Install: $install_hint"
        MISSING=$((MISSING + 1))
    fi
}

echo "Checking required tools..."
echo ""

# --- AWS CLI ---
check_tool "aws" "https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"

# --- eksctl (creates EKS clusters) ---
check_tool "eksctl" "brew install eksctl  OR  https://eksctl.io/installation/"

# --- kubectl (talks to Kubernetes) ---
check_tool "kubectl" "brew install kubectl  OR  https://kubernetes.io/docs/tasks/tools/"

# --- helm (Kubernetes package manager) ---
check_tool "helm" "brew install helm  OR  https://helm.sh/docs/intro/install/"

# --- curl (for testing the model endpoint) ---
check_tool "curl" "Should be pre-installed on most systems"

# --- jq (for parsing JSON responses) ---
check_tool "jq" "brew install jq  OR  https://jqlang.github.io/jq/download/"

echo ""

# ---------- Check AWS credentials ----------
echo "Checking AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "  ✅  AWS credentials configured (Account: $ACCOUNT_ID)"
else
    echo "  ❌  AWS credentials NOT configured"
    echo "      Run: aws configure"
    MISSING=$((MISSING + 1))
fi

echo ""

# ---------- Final verdict ----------
if [ "$MISSING" -gt 0 ]; then
    echo "=============================================="
    echo "  ❌ FAILED: $MISSING tool(s) missing"
    echo "  Please install them and re-run this script"
    echo "=============================================="
    exit 1
else
    echo "=============================================="
    echo "  ✅ ALL GOOD! You're ready to go."
    echo "  Next step: ./01-create-eks-cluster.sh"
    echo "=============================================="
fi
