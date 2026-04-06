#!/bin/bash
# ==============================================================================
# Run lab steps (assumes EKS already exists — create it with ./01-create-eks-cluster.sh)
# ==============================================================================
# Does not run: 01-create-eks-cluster (to avoid accidental cost), 03-watch (interactive),
#               05-cleanup-lab, 06-delete-eks-cluster
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Lab 3: vLLM on CPU (OpenAI-compatible API)      ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Prerequisite: ./01-create-eks-cluster.sh already completed (or any EKS with kubectl)."
echo "  Optional live demo between deploy and test: ./03-watch-vllm-live.sh"
echo ""

bash "$SCRIPT_DIR/00-prerequisites-check.sh"
echo ""
bash "$SCRIPT_DIR/02-deploy-vllm.sh"
echo ""
bash "$SCRIPT_DIR/04-test-chat.sh"
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Done. Remove workload: ./05-cleanup-lab.sh      ║"
echo "║  Delete entire cluster: ./06-delete-eks-cluster.sh ║"
echo "╚══════════════════════════════════════════════════╝"
