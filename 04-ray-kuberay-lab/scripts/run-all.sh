#!/bin/bash
# ==============================================================================
# Full path: operator → RayCluster → test (assumes kubectl context + cluster exist)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Lab 4: Ray + KubeRay on Kubernetes              ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

bash "$SCRIPT_DIR/00-prerequisites-check.sh"
echo ""
bash "$SCRIPT_DIR/02-install-kuberay.sh"
echo ""
bash "$SCRIPT_DIR/03-deploy-ray-cluster.sh"
echo ""
bash "$SCRIPT_DIR/05-test-ray-remote.sh"
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Optional: ./04-port-forward-dashboard.sh        ║"
echo "║  Cleanup:  ./06-cleanup-lab.sh                   ║"
echo "╚══════════════════════════════════════════════════╝"
