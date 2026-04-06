#!/bin/bash
# ==============================================================================
# STEP 0: Prepare Models (runs on YOUR LAPTOP, not the cluster)
# ==============================================================================
# What:  1. Installs Python dependencies (including onnxscript)
#        2. Converts Iris model -> ONNX
#        3. Converts Sentiment model -> ONNX
#        4. Creates Triton model repository structure
# Time:  ~3-5 minutes (mostly downloading the sentiment model)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$SCRIPT_DIR/.."
MODELS_DIR="$LAB_DIR/models"

echo "=============================================="
echo "  Step 0: Preparing Triton Models"
echo "=============================================="
echo ""

# ---- Install Python dependencies ----
echo "[1/3] Installing Python dependencies..."
pip install -r "$LAB_DIR/requirements.txt" -q
echo "   DONE"
echo ""

# ---- Convert Iris -> ONNX ----
echo "[2/3] Converting Iris model to ONNX..."
cd "$MODELS_DIR"
python convert-iris-onnx.py
echo ""

# ---- Convert Sentiment -> ONNX ----
echo "[3/3] Converting Sentiment model to ONNX..."
python convert-sentiment-onnx.py
echo ""

echo "=============================================="
echo "  Models ready!"
echo ""
echo "  Created:"
echo "    model-repo/iris-onnx/         <- Iris ONNX model"
echo "    model-repo/sentiment-onnx/    <- Sentiment ONNX model"
echo "    model-repo/tokenizer/         <- Tokenizer for test script"
echo ""
echo "  Next step: ./01-setup-s3-and-credentials.sh"
echo "=============================================="
