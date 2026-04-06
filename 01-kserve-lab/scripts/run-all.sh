#!/bin/bash
# ==============================================================================
# MASTER SCRIPT: Run the Entire KServe Lab (Start to Finish)
# ==============================================================================
# What:  Runs all steps in order: prerequisites → cluster → install → deploy → test
# Why:   One command to set everything up for the demo
# Time:  ~25-30 minutes total
#
# Usage:
#   ./run-all.sh          → Run everything
#   ./run-all.sh --skip-cluster  → Skip cluster creation (if already exists)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP_CLUSTER=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-cluster) SKIP_CLUSTER=true ;;
    esac
done

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║                                                  ║"
echo "║          KServe Lab - Full Setup                 ║"
echo "║                                                  ║"
echo "║  This will:                                      ║"
echo "║    1. Check prerequisites                        ║"
echo "║    2. Create EKS cluster (2 nodes)               ║"
echo "║    3. Install cert-manager                       ║"
echo "║    4. Install Istio                              ║"
echo "║    5. Install KServe                             ║"
echo "║    6. Deploy a sample ML model                   ║"
echo "║    7. Test inference                             ║"
echo "║                                                  ║"
echo "║  Estimated time: ~25-30 minutes                  ║"
echo "║  Estimated cost: ~\$0.20/hr                       ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Track timing
TOTAL_START=$(date +%s)

# ---------- Step 0: Prerequisites ----------
step_start=$(date +%s)
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RUNNING STEP 0/6: Prerequisites Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/00-prerequisites-check.sh"
step_end=$(date +%s)
echo "  ⏱️  Step 0 took $((step_end - step_start)) seconds"
echo ""

# ---------- Step 1: Create Cluster ----------
if [ "$SKIP_CLUSTER" = false ]; then
    step_start=$(date +%s)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  RUNNING STEP 1/6: Create EKS Cluster"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bash "$SCRIPT_DIR/01-create-eks-cluster.sh"
    step_end=$(date +%s)
    echo "  ⏱️  Step 1 took $((step_end - step_start)) seconds"
    echo ""
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  SKIPPING STEP 1: Cluster creation (--skip-cluster)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# ---------- Step 2: cert-manager ----------
step_start=$(date +%s)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RUNNING STEP 2/6: Install cert-manager"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/02-install-cert-manager.sh"
step_end=$(date +%s)
echo "  ⏱️  Step 2 took $((step_end - step_start)) seconds"
echo ""

# ---------- Step 3: Istio ----------
step_start=$(date +%s)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RUNNING STEP 3/6: Install Istio"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/03-install-istio.sh"
step_end=$(date +%s)
echo "  ⏱️  Step 3 took $((step_end - step_start)) seconds"
echo ""

# ---------- Step 4: KServe ----------
step_start=$(date +%s)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RUNNING STEP 4/6: Install KServe"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/04-install-kserve.sh"
step_end=$(date +%s)
echo "  ⏱️  Step 4 took $((step_end - step_start)) seconds"
echo ""

# ---------- Step 5: Deploy Model ----------
step_start=$(date +%s)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RUNNING STEP 5/6: Deploy Model"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/05-deploy-model.sh"
step_end=$(date +%s)
echo "  ⏱️  Step 5 took $((step_end - step_start)) seconds"
echo ""

# ---------- Step 6: Test ----------
step_start=$(date +%s)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RUNNING STEP 6/6: Test Inference"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/06-test-inference.sh"
step_end=$(date +%s)
echo "  ⏱️  Step 6 took $((step_end - step_start)) seconds"
echo ""

# ---------- Summary ----------
TOTAL_END=$(date +%s)
TOTAL_TIME=$((TOTAL_END - TOTAL_START))
TOTAL_MIN=$((TOTAL_TIME / 60))
TOTAL_SEC=$((TOTAL_TIME % 60))

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║                                                  ║"
echo "║          🎉 KServe Lab Complete! 🎉              ║"
echo "║                                                  ║"
echo "║  Total time: ${TOTAL_MIN}m ${TOTAL_SEC}s                          ║"
echo "║                                                  ║"
echo "║  What's running:                                 ║"
echo "║    ✅ EKS Cluster (2 nodes)                      ║"
echo "║    ✅ cert-manager                               ║"
echo "║    ✅ Istio Service Mesh                         ║"
echo "║    ✅ KServe (RawDeployment mode)                 ║"
echo "║    ✅ 3 Models: sklearn + xgboost + canary      ║"
echo "║                                                  ║"
echo "║  ⚠️  Don't forget to run 07-cleanup.sh          ║"
echo "║     when you're done to save money!              ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
