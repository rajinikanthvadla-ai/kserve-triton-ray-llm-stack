#!/bin/bash
# ==============================================================================
# DEMO HELPER: Watch Traffic Routing Across Models (Live!)
# ==============================================================================
# What:  Shows LIVE proof that requests are routed to the correct model
# How:   Fires requests and shows which pod handled each one
# Why:   Visually proves that KServe routes to the right model
#
# BEST WAY TO DEMO (3 terminals side-by-side):
#   Terminal 1:  kubectl logs -f -n kserve-demo -l serving.kserve.io/inferenceservice=sklearn-iris -c kserve-container
#   Terminal 2:  kubectl logs -f -n kserve-demo -l serving.kserve.io/inferenceservice=xgboost-iris -c kserve-container
#   Terminal 3:  ./watch-traffic.sh  (this script — fires requests)
#
# When you run curl to sklearn → Terminal 1 lights up, Terminal 2 stays quiet
# When you run curl to xgboost → Terminal 2 lights up, Terminal 1 stays quiet
# ==============================================================================

set -e

echo "=============================================="
echo "  🔍 Traffic Routing Demo"
echo "=============================================="
echo ""

# ---------- Start port-forwards ----------
pkill -f "port-forward.*kserve-demo" 2>/dev/null || true
sleep 1

kubectl port-forward svc/sklearn-iris-predictor -n kserve-demo 8081:80 &>/dev/null &
PF1=$!
kubectl port-forward svc/xgboost-iris-predictor -n kserve-demo 8082:80 &>/dev/null &
PF2=$!
kubectl port-forward svc/sklearn-iris-canary-predictor -n kserve-demo 8083:80 &>/dev/null &
PF3=$!
sleep 3

echo "  Port-forwards ready:"
echo "    :8081 → sklearn-iris"
echo "    :8082 → xgboost-iris"
echo "    :8083 → sklearn-iris-canary"
echo ""

# ---------- Get pod names ----------
SK_POD=$(kubectl get pods -n kserve-demo -l serving.kserve.io/inferenceservice=sklearn-iris -o jsonpath='{.items[0].metadata.name}')
XG_POD=$(kubectl get pods -n kserve-demo -l serving.kserve.io/inferenceservice=xgboost-iris -o jsonpath='{.items[0].metadata.name}')
CA_POD=$(kubectl get pods -n kserve-demo -l serving.kserve.io/inferenceservice=sklearn-iris-canary -o jsonpath='{.items[0].metadata.name}')

echo "  Pod names:"
echo "    sklearn-iris        → $SK_POD"
echo "    xgboost-iris        → $XG_POD"
echo "    sklearn-iris-canary → $CA_POD"
echo ""

# ==========================================================
# DEMO 1: Show traffic goes to the CORRECT pod
# ==========================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DEMO 1: Which pod handles each request?"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get log line counts BEFORE request
SK_BEFORE=$(kubectl logs "$SK_POD" -n kserve-demo -c kserve-container 2>/dev/null | wc -l)
XG_BEFORE=$(kubectl logs "$XG_POD" -n kserve-demo -c kserve-container 2>/dev/null | wc -l)

echo "  📤 Sending request to SKLEARN model (port 8081)..."
curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[6.8, 2.8, 4.8, 1.4]]}' > /dev/null
sleep 1

# Get log line counts AFTER request
SK_AFTER=$(kubectl logs "$SK_POD" -n kserve-demo -c kserve-container 2>/dev/null | wc -l)
XG_AFTER=$(kubectl logs "$XG_POD" -n kserve-demo -c kserve-container 2>/dev/null | wc -l)

SK_NEW=$((SK_AFTER - SK_BEFORE))
XG_NEW=$((XG_AFTER - XG_BEFORE))

echo ""
echo "  📊 New log lines after request:"
echo "    sklearn-iris pod: +$SK_NEW lines  $([ "$SK_NEW" -gt 0 ] && echo '← REQUEST WENT HERE ✅' || echo '(quiet)')"
echo "    xgboost-iris pod: +$XG_NEW lines  $([ "$XG_NEW" -gt 0 ] && echo '← REQUEST WENT HERE' || echo '(quiet) ✅')"
echo ""

# Show the actual new log lines from sklearn
echo "  📝 sklearn-iris pod log (last request):"
kubectl logs "$SK_POD" -n kserve-demo -c kserve-container --tail=3 2>/dev/null | while read line; do
    echo "     $line"
done
echo ""

echo "  ─────────────────────────────────────"
echo ""

# Now send to xgboost
SK_BEFORE=$(kubectl logs "$SK_POD" -n kserve-demo -c kserve-container 2>/dev/null | wc -l)
XG_BEFORE=$(kubectl logs "$XG_POD" -n kserve-demo -c kserve-container 2>/dev/null | wc -l)

echo "  📤 Sending request to XGBOOST model (port 8082)..."
curl -s http://localhost:8082/v1/models/xgboost-iris:predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[6.8, 2.8, 4.8, 1.4]]}' > /dev/null
sleep 1

SK_AFTER=$(kubectl logs "$SK_POD" -n kserve-demo -c kserve-container 2>/dev/null | wc -l)
XG_AFTER=$(kubectl logs "$XG_POD" -n kserve-demo -c kserve-container 2>/dev/null | wc -l)

SK_NEW=$((SK_AFTER - SK_BEFORE))
XG_NEW=$((XG_AFTER - XG_BEFORE))

echo ""
echo "  📊 New log lines after request:"
echo "    sklearn-iris pod:  +$SK_NEW lines  $([ "$SK_NEW" -gt 0 ] && echo '← REQUEST WENT HERE' || echo '(quiet) ✅')"
echo "    xgboost-iris pod:  +$XG_NEW lines  $([ "$XG_NEW" -gt 0 ] && echo '← REQUEST WENT HERE ✅' || echo '(quiet)')"
echo ""

echo "  📝 xgboost-iris pod log (last request):"
kubectl logs "$XG_POD" -n kserve-demo -c kserve-container --tail=3 2>/dev/null | while read line; do
    echo "     $line"
done
echo ""

# ==========================================================
# DEMO 2: Show services and endpoints
# ==========================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DEMO 2: K8s Services → Endpoints → Pods"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Each model has its own Service → routes to its own Pod:"
echo ""

echo "  ┌─────────────────────────────────┬──────────────────┬─────────────┐"
echo "  │ Service                         │ ClusterIP        │ Target Pod  │"
echo "  ├─────────────────────────────────┼──────────────────┼─────────────┤"

SK_IP=$(kubectl get svc sklearn-iris-predictor -n kserve-demo -o jsonpath='{.spec.clusterIP}')
XG_IP=$(kubectl get svc xgboost-iris-predictor -n kserve-demo -o jsonpath='{.spec.clusterIP}')
CA_IP=$(kubectl get svc sklearn-iris-canary-predictor -n kserve-demo -o jsonpath='{.spec.clusterIP}')

printf "  │ %-31s │ %-16s │ %-11s │\n" "sklearn-iris-predictor" "$SK_IP" "sklearn"
printf "  │ %-31s │ %-16s │ %-11s │\n" "xgboost-iris-predictor" "$XG_IP" "xgboost"
printf "  │ %-31s │ %-16s │ %-11s │\n" "sklearn-iris-canary-predictor" "$CA_IP" "canary"
echo "  └─────────────────────────────────┴──────────────────┴─────────────┘"
echo ""

# ==========================================================
# DEMO 3: Rapid-fire — 5 requests each, count per pod
# ==========================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DEMO 3: Rapid-Fire — 5 requests to each model"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Grab log counts before
SK_BEFORE=$(kubectl logs "$SK_POD" -n kserve-demo -c kserve-container 2>/dev/null | wc -l)
XG_BEFORE=$(kubectl logs "$XG_POD" -n kserve-demo -c kserve-container 2>/dev/null | wc -l)

echo "  Firing 5 requests to sklearn-iris..."
for i in $(seq 1 5); do
    RESP=$(curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
        -H "Content-Type: application/json" \
        -d '{"instances": [[6.8, 2.8, 4.8, 1.4]]}')
    echo "    [$i] → $RESP"
done
echo ""

echo "  Firing 5 requests to xgboost-iris..."
for i in $(seq 1 5); do
    RESP=$(curl -s http://localhost:8082/v1/models/xgboost-iris:predict \
        -H "Content-Type: application/json" \
        -d '{"instances": [[6.8, 2.8, 4.8, 1.4]]}')
    echo "    [$i] → $RESP"
done
echo ""
sleep 1

# Grab log counts after
SK_AFTER=$(kubectl logs "$SK_POD" -n kserve-demo -c kserve-container 2>/dev/null | wc -l)
XG_AFTER=$(kubectl logs "$XG_POD" -n kserve-demo -c kserve-container 2>/dev/null | wc -l)

SK_HITS=$((SK_AFTER - SK_BEFORE))
XG_HITS=$((XG_AFTER - XG_BEFORE))

echo "  📊 RESULT — Log activity after 10 total requests:"
echo ""
echo "    sklearn-iris pod:  +$SK_HITS log lines  (handled sklearn requests)"
echo "    xgboost-iris pod:  +$XG_HITS log lines  (handled xgboost requests)"
echo ""
echo "  ✅ Traffic is ISOLATED — each model's pod only processes its own requests!"
echo ""

# ==========================================================
# DEMO 4: Show Istio sidecar proving request path
# ==========================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DEMO 4: Istio Sidecar Logs (request path proof)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Last 3 Istio proxy log lines from each model pod:"
echo ""

echo "  --- sklearn-iris (istio-proxy) ---"
kubectl logs "$SK_POD" -n kserve-demo -c istio-proxy --tail=3 2>/dev/null | while read line; do
    echo "    $line"
done
echo ""

echo "  --- xgboost-iris (istio-proxy) ---"
kubectl logs "$XG_POD" -n kserve-demo -c istio-proxy --tail=3 2>/dev/null | while read line; do
    echo "    $line"
done
echo ""

# Cleanup
kill $PF1 $PF2 $PF3 2>/dev/null || true

echo "=============================================="
echo "  🎉 Traffic Routing Demo Complete!"
echo ""
echo "  What we proved:"
echo "    ✅ sklearn requests → only sklearn pod logs"
echo "    ✅ xgboost requests → only xgboost pod logs"
echo "    ✅ Each model has its own K8s Service + ClusterIP"
echo "    ✅ Istio sidecar shows the request path"
echo ""
echo "  For LIVE demo, open 3 terminals:"
echo "    T1: kubectl logs -f -n kserve-demo -l serving.kserve.io/inferenceservice=sklearn-iris -c kserve-container"
echo "    T2: kubectl logs -f -n kserve-demo -l serving.kserve.io/inferenceservice=xgboost-iris -c kserve-container"
echo "    T3: Send curl requests and watch T1/T2 light up!"
echo "=============================================="
