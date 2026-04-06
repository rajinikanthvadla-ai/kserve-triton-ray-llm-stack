#!/bin/bash
# ==============================================================================
# Apply RayCluster CR (KubeRay creates head/worker Pods + Services)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"
NS="ray-lab"

echo "=============================================="
echo "  Step 3: Deploy RayCluster (ray-lab-mini)"
echo "=============================================="

kubectl apply -f "$MANIFESTS_DIR/namespace.yaml"
kubectl apply -f "$MANIFESTS_DIR/ray-cluster.yaml"

echo ""
echo "Waiting for Ray head Pod to be Ready (image pull can take several minutes)..."
for i in $(seq 1 120); do
  if kubectl get pods -n "$NS" -l ray.io/node-type=head --no-headers 2>/dev/null | grep -q .; then
    break
  fi
  echo "  ... waiting for head pod ($i)"
  sleep 5
done

kubectl wait --for=condition=Ready pod \
  -l ray.io/node-type=head \
  -n "$NS" \
  --timeout=600s

echo ""
kubectl get raycluster -n "$NS"
kubectl get pods -n "$NS" -o wide
kubectl get svc -n "$NS"
echo ""
echo "=============================================="
echo "  ✅ RayCluster is up"
echo "  Next: ./05-test-ray-remote.sh"
echo "  Dashboard: ./04-port-forward-dashboard.sh (separate terminal)"
echo "=============================================="
