#!/bin/bash
# ==============================================================================
# MASTER SCRIPT: Run the Entire Triton Lab
# ==============================================================================
# What:  Runs all steps: prepare → upload → deploy → test → features
# Time:  ~10-15 minutes
#
# Prerequisites:
#   - EKS cluster running (from Lab 1)
#   - KServe installed (from Lab 1)
#   - Python 3.x with pip
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║                                                  ║"
echo "║     Lab 2: Triton Inference Server               ║"
echo "║                                                  ║"
echo "║  This will:                                      ║"
echo "║    0. Convert models to ONNX (local)             ║"
echo "║    1. Upload to S3 + setup credentials           ║"
echo "║    2. Deploy on Triton via KServe                ║"
echo "║    3. Test both models                           ║"
echo "║    4. Demo Triton-specific features              ║"
echo "║                                                  ║"
echo "║  Models:                                         ║"
echo "║    📊 Iris classifier (ONNX on Triton)           ║"
echo "║    📝 Sentiment analysis (ONNX on Triton)        ║"
echo "║                                                  ║"
echo "║  Estimated time: ~10-15 minutes                  ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

TOTAL_START=$(date +%s)

# Step 0
step_start=$(date +%s)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 0/4: Prepare Models (ONNX conversion)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/00-prepare-models.sh"
step_end=$(date +%s)
echo "  ⏱️  Step 0 took $((step_end - step_start)) seconds"
echo ""

# Step 1
step_start=$(date +%s)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 1/4: S3 Upload + Credentials"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/01-setup-s3-and-credentials.sh"
step_end=$(date +%s)
echo "  ⏱️  Step 1 took $((step_end - step_start)) seconds"
echo ""

# Step 2
step_start=$(date +%s)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 2/4: Deploy Triton Models"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/02-deploy-triton-models.sh"
step_end=$(date +%s)
echo "  ⏱️  Step 2 took $((step_end - step_start)) seconds"
echo ""

# Step 3
step_start=$(date +%s)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 3/4: Test Models"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/03-test-inference.sh"
step_end=$(date +%s)
echo "  ⏱️  Step 3 took $((step_end - step_start)) seconds"
echo ""

# Step 4
step_start=$(date +%s)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 4/4: Triton Features Demo"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/04-triton-features.sh"
step_end=$(date +%s)
echo "  ⏱️  Step 4 took $((step_end - step_start)) seconds"
echo ""

# Summary
TOTAL_END=$(date +%s)
TOTAL_TIME=$((TOTAL_END - TOTAL_START))
TOTAL_MIN=$((TOTAL_TIME / 60))
TOTAL_SEC=$((TOTAL_TIME % 60))

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║                                                  ║"
echo "║     🎉 Triton Lab Complete! 🎉                   ║"
echo "║                                                  ║"
echo "║  Total time: ${TOTAL_MIN}m ${TOTAL_SEC}s                          ║"
echo "║                                                  ║"
echo "║  What's running:                                 ║"
echo "║    ✅ Iris ONNX on Triton                        ║"
echo "║    ✅ Sentiment ONNX on Triton                   ║"
echo "║                                                  ║"
echo "║  ⚠️  Run 05-cleanup.sh when done!               ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
