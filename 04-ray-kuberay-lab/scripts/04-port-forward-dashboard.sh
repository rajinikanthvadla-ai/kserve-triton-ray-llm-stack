#!/bin/bash
# ==============================================================================
# Ray Dashboard — http://127.0.0.1:8265 (blocks; Ctrl+C to stop)
# ==============================================================================
set -e

NS="ray-lab"
CLUSTER="ray-lab-mini"
# KubeRay names the head Service: <RayCluster.metadata.name>-head-svc
SVC="${CLUSTER}-head-svc"
LOCAL_PORT="${DASHBOARD_PORT:-8265}"

echo "=============================================="
echo "  Ray Dashboard port-forward"
echo "=============================================="
echo "  Open: http://127.0.0.1:${LOCAL_PORT}"
echo "  Service: ${NS}/${SVC}"
echo "  Press Ctrl+C to stop."
echo "=============================================="
echo ""

kubectl port-forward -n "$NS" "svc/$SVC" "${LOCAL_PORT}:8265"
