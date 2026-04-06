#!/bin/bash
# ==============================================================================
# Run a minimal @ray.remote task inside the head pod (proves Ray runtime works)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLES_DIR="$SCRIPT_DIR/../examples"
NS="ray-lab"
# Git Bash / MSYS rewrites /tmp/... to C:/Users/.../AppData/Local/Temp/ — breaks paths sent to the container.
export MSYS_NO_PATHCONV=1

echo "=============================================="
echo "  Step 5: Test Ray remote task (in-cluster)"
echo "=============================================="

HEAD_POD=$(kubectl get pods -n "$NS" -l ray.io/node-type=head -o jsonpath='{.items[0].metadata.name}')
if [ -z "$HEAD_POD" ]; then
  echo "❌ No head pod in $NS. Run ./03-deploy-ray-cluster.sh first."
  exit 1
fi

echo "  Head pod: $HEAD_POD"
# Avoid kubectl cp — it breaks on Windows/Git Bash ("one of src or dest must be a local file specification").
kubectl exec -n "$NS" "$HEAD_POD" -i -- sh -c 'cat > /tmp/hello_ray.py' < "$EXAMPLES_DIR/hello_ray.py"
echo ""
echo "--- python /tmp/hello_ray.py (via sh -c so /tmp is not rewritten by Git Bash) ---"
kubectl exec -n "$NS" "$HEAD_POD" -- sh -c 'python /tmp/hello_ray.py'
echo ""
echo "=============================================="
echo "  ✅ Ray remote task succeeded"
echo "=============================================="
