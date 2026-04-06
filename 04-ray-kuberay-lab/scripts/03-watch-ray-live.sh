#!/bin/bash
# ==============================================================================
# Stream Ray head pod logs (image pull → ray start → dashboard)
# ==============================================================================
set -e

NS="ray-lab"
DEPLOY_NAME="ray-lab-mini"

echo "=============================================="
echo "  Live logs: Ray head (Ctrl+C to stop)"
echo "=============================================="
echo "Tip: kubectl get pods -n $NS -w"
echo ""

kubectl logs -f -n "$NS" -l ray.io/node-type=head --tail=50
