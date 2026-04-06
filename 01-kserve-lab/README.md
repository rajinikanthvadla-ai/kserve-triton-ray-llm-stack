# KServe Lab — Deploy ML Models on Kubernetes (EKS)

> **What you'll build:** A real, working ML model serving pipeline on AWS EKS using KServe.  
> **Time:** ~30 minutes | **Cost:** ~$5/day | **Difficulty:** Beginner-friendly

---

## What is KServe?

KServe is an open-source platform for serving machine learning models on Kubernetes. Think of it as **"Heroku for ML models"** — you give it a trained model, and it turns that model into a production-ready REST API.

**Without KServe**, deploying a model means:
- Writing a Flask/FastAPI server yourself
- Handling scaling, health checks, load balancing
- Managing Docker images, Kubernetes deployments, services...

**With KServe**, you write ONE YAML file, and it handles everything.

---

## Architecture (What We're Building)

```
┌──────────────────────────────────────────────────────────────────────┐
│                        AWS EKS Cluster                               │
│                      (2x t3.medium nodes)                            │
│                                                                      │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────────┐  │
│  │ cert-manager │  │    Istio     │  │          KServe             │  │
│  │  (TLS certs) │  │ (networking) │  │      (model serving)        │  │
│  └─────────────┘  └──────┬───────┘  └────────────┬────────────────┘  │
│                          │                       │                    │
│                   ┌──────▼───────┐    ┌──────────▼─────────────┐     │
│                   │    Istio     │    │  Model #1: sklearn-iris │     │
│                   │   Gateway    │───▶│  Model #2: xgboost-iris│     │
│                   │ (front door) │    │  Model #3: canary (80/20)│   │
│                   └──────────────┘    └────────────────────────┘     │
│                          ▲                                           │
└──────────────────────────┼───────────────────────────────────────────┘
                           │
                    ┌──────┴──────┐
                    │  Your curl  │
                    │  requests   │
                    └─────────────┘
```

**3 models deployed:**
1. **sklearn-iris** — SKLearn Iris classifier
2. **xgboost-iris** — XGBoost Iris classifier (same data, different algorithm)
3. **sklearn-iris-canary** — Canary deployment (80/20 traffic split demo)

---

## Prerequisites

Install these tools **before** starting:

| Tool | What it does | Install |
|------|-------------|---------|
| **AWS CLI** | Talks to AWS | [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| **eksctl** | Creates EKS clusters | `brew install eksctl` or [eksctl.io](https://eksctl.io/installation/) |
| **kubectl** | Talks to Kubernetes | `brew install kubectl` or [k8s docs](https://kubernetes.io/docs/tasks/tools/) |
| **helm** | Kubernetes package manager | `brew install helm` or [helm.sh](https://helm.sh/docs/intro/install/) |
| **curl** | Sends HTTP requests | Pre-installed on Mac/Linux |
| **jq** | Parses JSON | `brew install jq` |

Also: **AWS credentials must be configured** (`aws configure`).

---

## Project Structure

```
01-kserve-lab/
├── scripts/
│   ├── 00-prerequisites-check.sh    ← Check if tools are installed
│   ├── 01-create-eks-cluster.sh     ← Create the EKS cluster (2 nodes)
│   ├── 02-install-cert-manager.sh   ← Install TLS certificate manager
│   ├── 03-install-istio.sh          ← Install Istio networking layer
│   ├── 04-install-kserve.sh         ← Install KServe (the main thing!)
│   ├── 05-deploy-model.sh           ← Deploy 3 models (sklearn + xgboost + canary)
│   ├── 06-test-inference.sh         ← Test all models + compare + traffic split
│   ├── 07-cleanup.sh                ← DELETE everything (save money!)
│   ├── run-all.sh                   ← Run steps 0-6 automatically
│   └── watch-traffic.sh             ← Live traffic routing demo
├── manifests/
│   ├── eks-cluster.yaml                        ← EKS cluster config
│   ├── sklearn-iris-inferenceservice.yaml      ← Model #1: SKLearn
│   ├── xgboost-iris-inferenceservice.yaml      ← Model #2: XGBoost
│   └── sklearn-iris-canary.yaml                ← Model #3: Canary traffic split
└── README.md                                   ← You are here!
```

---

## Quick Start (One Command)

```bash
cd 01-kserve-lab/scripts
chmod +x *.sh
./run-all.sh
```

This takes ~25-30 minutes and sets up everything from scratch.

---

## Step-by-Step Guide (Recommended)

### Step 0: Check Prerequisites (~5 seconds)

```bash
cd 01-kserve-lab/scripts
chmod +x *.sh
./00-prerequisites-check.sh
```

**What it does:** Checks that all CLI tools are installed and AWS credentials work.  
**Expected output:** Green checkmarks ✅ for each tool.

---

### Step 1: Create EKS Cluster (~15-20 minutes)

```bash
./01-create-eks-cluster.sh
```

**What it does:**
- Creates an EKS cluster called `kserve-lab` in `ap-south-1`
- Launches 2x `t3.medium` EC2 instances (2 vCPU, 4GB RAM each)
- Configures `kubectl` to talk to this cluster

**Cost breakdown:**
| Resource | Cost/hr |
|----------|---------|
| EKS Control Plane | $0.10 |
| t3.medium Node 1 | $0.0416 |
| t3.medium Node 2 | $0.0416 |
| **Total** | **~$0.18/hr** |

**From my experience:** EKS = managed Kubernetes. AWS handles the control plane (API server, etcd, scheduler). We only pay for the worker nodes + a flat $0.10/hr management fee.

---

### Step 2: Install cert-manager (~2-3 minutes)

```bash
./02-install-cert-manager.sh
```

**What it does:** Installs cert-manager via Helm.  
**Why we need it:** KServe's webhooks need TLS certificates. cert-manager creates and renews these automatically.

**From my experience:** Kubernetes admission webhooks validate resources before they're created. These webhooks need HTTPS (TLS certs). Without cert-manager, you'd have to manually create and rotate certificates.

---

### Step 3: Install Istio (~3-5 minutes)

```bash
./03-install-istio.sh
```

**What it does:** Installs the Istio service mesh (3 components):
1. **istio-base** — Custom Resource Definitions (CRDs)
2. **istiod** — The control plane (the "brain" that configures networking)
3. **istio-ingress** — The gateway (the "front door" for external traffic)

**From my experience:** KServe needs Istio to:
- Route HTTP requests to the correct model
- Handle traffic splitting (canary deployments)
- Provide the external LoadBalancer endpoint

---

### Step 4: Install KServe (~3-5 minutes)

```bash
./04-install-kserve.sh
```

**What it does:** Installs KServe itself (2 Helm charts):
1. **kserve-crd** — The InferenceService CRD (defines the "InferenceService" resource type)
2. **kserve** — The controller (watches for InferenceService objects and deploys models)

**From my experience:** After this step, Kubernetes now understands a new resource type: `InferenceService`. When you create one, the KServe controller automatically:
- Pulls your model from storage
- Creates a model server pod
- Sets up routing via Istio
- Configures auto-scaling

---

### Step 5: Deploy 3 Models (~3-5 minutes)

```bash
./05-deploy-model.sh
```

**What it does:** Deploys THREE InferenceServices:

| # | Name | Framework | What it shows |
|---|------|-----------|---------------|
| 1 | `sklearn-iris` | Scikit-learn | Basic model serving |
| 2 | `xgboost-iris` | XGBoost | Multi-framework support |
| 3 | `sklearn-iris-canary` | Scikit-learn | Canary traffic split (80/20) |

**From my experience:** Notice the YAML for XGBoost is almost identical to SKLearn — you just change `modelFormat.name`! KServe abstracts away the framework differences.

---

### Step 6: Test All Models (~1 minute)

```bash
./06-test-inference.sh
```

Or use the **curl commands** below to test manually!

---

### Step 7: Cleanup (⚠️ IMPORTANT!)

```bash
./07-cleanup.sh
```

**⚠️ Don't forget this!** The cluster costs ~$5/day even when idle.

---

## 🧪 Curl Commands — Copy & Paste to Test!

> **Run these MANUALLY after Step 5 to test your models.**
> We use `kubectl port-forward` to reach the model services directly.

### First: Start Port-Forwards (one terminal window)

```bash
# Forward each model to a different local port
kubectl port-forward svc/sklearn-iris-predictor -n kserve-demo 8081:80 &
kubectl port-forward svc/xgboost-iris-predictor -n kserve-demo 8082:80 &
kubectl port-forward svc/sklearn-iris-canary-predictor -n kserve-demo 8083:80 &

# Now you can hit:
#   sklearn-iris        → http://localhost:8081
#   xgboost-iris        → http://localhost:8082
#   sklearn-iris-canary → http://localhost:8083
```

---

### Test 1: Hit the SKLearn Model

```bash
curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
  -H "Content-Type: application/json" \
  -d '{
    "instances": [
      [6.8, 2.8, 4.8, 1.4],
      [6.0, 3.4, 4.5, 1.6]
    ]
  }' | jq .
```

**Expected response:**
```json
{"predictions": [1, 1]}
```
> Both are class **1 = Versicolor**

---

### Test 2: Hit the XGBoost Model (same input, different framework!)

```bash
curl -s http://localhost:8082/v1/models/xgboost-iris:predict \
  -H "Content-Type: application/json" \
  -d '{
    "instances": [
      [6.8, 2.8, 4.8, 1.4],
      [6.0, 3.4, 4.5, 1.6]
    ]
  }' | jq .
```

**Expected response:**
```json
{"predictions": [1, 1]}
```
> Same input, same answer — but from a completely different ML framework! 🤯

---

### Test 3: Predict a Setosa flower 🌸

```bash
curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}' | jq .
```

**Expected:** `{"predictions": [0]}` → **Setosa** (class 0)

---

### Test 4: Predict a Virginica flower 🌷

```bash
curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[7.7, 3.8, 6.7, 2.2]]}' | jq .
```

**Expected:** `{"predictions": [2]}` → **Virginica** (class 2)

---

### Test 5: Compare SKLearn vs XGBoost (side by side)

```bash
echo "--- SKLearn prediction ---"
curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[5.9, 3.0, 5.1, 1.8]]}' | jq .

echo "--- XGBoost prediction ---"
curl -s http://localhost:8082/v1/models/xgboost-iris:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[5.9, 3.0, 5.1, 1.8]]}' | jq .
```

> This is a borderline sample — sometimes the two models disagree! Great for showing
> why you'd want to deploy multiple models and compare.

---

### Test 6: Canary Deployment

```bash
# Send 5 requests to the canary model
for i in $(seq 1 5); do
  echo "Request $i:"
  curl -s http://localhost:8083/v1/models/sklearn-iris-canary:predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[6.8, 2.8, 4.8, 1.4]]}'
  echo ""
done
```

---

### Test 7: Health Check All Models

```bash
# Check if sklearn-iris is healthy
curl -s http://localhost:8081/v1/models/sklearn-iris | jq .

# Check if xgboost-iris is healthy
curl -s http://localhost:8082/v1/models/xgboost-iris | jq .

# Check if canary is healthy
curl -s http://localhost:8083/v1/models/sklearn-iris-canary | jq .
```

---

### Test 8: Batch Prediction (multiple samples at once)

```bash
curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
  -H "Content-Type: application/json" \
  -d '{
    "instances": [
      [5.1, 3.5, 1.4, 0.2],
      [6.7, 3.0, 5.0, 1.7],
      [7.7, 3.8, 6.7, 2.2],
      [4.9, 3.1, 1.5, 0.1],
      [6.3, 2.5, 4.9, 1.5]
    ]
  }' | jq .
```

**Expected:**
```json
{"predictions": [0, 1, 2, 0, 1]}
```
> Setosa, Versicolor, Virginica, Setosa, Versicolor — all 3 classes in one request!

---

### Done testing? Kill port-forwards:

```bash
pkill -f "port-forward.*kserve-demo"
```

---

## Quick Reference: Input → Output

| Input (sepal_l, sepal_w, petal_l, petal_w) | Expected Class | Flower |
|---|---|---|
| `[5.1, 3.5, 1.4, 0.2]` | 0 | 🌸 Setosa |
| `[4.9, 3.1, 1.5, 0.1]` | 0 | 🌸 Setosa |
| `[6.7, 3.0, 5.0, 1.7]` | 1 | 🌺 Versicolor |
| `[6.8, 2.8, 4.8, 1.4]` | 1 | 🌺 Versicolor |
| `[6.0, 3.4, 4.5, 1.6]` | 1 | 🌺 Versicolor |
| `[7.7, 3.8, 6.7, 2.2]` | 2 | 🌷 Virginica |
| `[5.9, 3.0, 5.1, 1.8]` | 2 | 🌷 Virginica |

---

## 🔍 Live Traffic Routing Demo

> **This is the PROOF that KServe routes traffic to the correct model.**
> Open 3 Git Bash windows side-by-side and watch the logs light up in real time.

You can also run the automated version: `./watch-traffic.sh`

### Setup: Open 3 Terminals Side-by-Side

**Terminal 1 (LEFT) — Watch sklearn-iris logs:**

```bash
kubectl logs -f -n kserve-demo \
  -l serving.kserve.io/inferenceservice=sklearn-iris \
  -c kserve-container
```

**Terminal 2 (MIDDLE) — Watch xgboost-iris logs:**

```bash
kubectl logs -f -n kserve-demo \
  -l serving.kserve.io/inferenceservice=xgboost-iris \
  -c kserve-container
```

**Terminal 3 (RIGHT) — Start port-forwards + fire requests:**

```bash
kubectl port-forward svc/sklearn-iris-predictor -n kserve-demo 8081:80 &
kubectl port-forward svc/xgboost-iris-predictor -n kserve-demo 8082:80 &
sleep 2
```

### Demo Step 1: "Watch Terminal 1..." — hit sklearn

```bash
curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[6.8, 2.8, 4.8, 1.4]]}'
```

> 👉 **Terminal 1 lights up** with log lines, Terminal 2 stays **silent**

### Demo Step 2: "Now watch Terminal 2..." — hit xgboost

```bash
curl -s http://localhost:8082/v1/models/xgboost-iris:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[6.8, 2.8, 4.8, 1.4]]}'
```

> 👉 **Terminal 2 lights up**, Terminal 1 stays **silent**

### Demo Step 3: "Let's blast 10 requests..." — rapid fire

```bash
for i in $(seq 1 10); do
  echo "--- Request $i to SKLEARN ---"
  curl -s http://localhost:8081/v1/models/sklearn-iris:predict \
    -H "Content-Type: application/json" \
    -d '{"instances": [[6.8, 2.8, 4.8, 1.4]]}'
  echo ""
done
```

> 👉 Terminal 1 goes **CRAZY** with logs, Terminal 2 dead quiet. **PROOF that traffic is isolated!**

### Demo Step 4: Show K8s routing — Services & Endpoints

```bash
# Each model has its own Kubernetes Service with its own ClusterIP
kubectl get svc -n kserve-demo

# Each service targets ONLY its own pod (look at the ENDPOINTS column)
kubectl get endpoints -n kserve-demo

# Show which pod each service routes to
kubectl describe svc sklearn-iris-predictor -n kserve-demo | grep -E "Name:|Selector:|Endpoints:"
kubectl describe svc xgboost-iris-predictor -n kserve-demo | grep -E "Name:|Selector:|Endpoints:"
```

### Demo Step 5: Show Istio sidecar logs (request path proof)

```bash
# Istio proxy logs from sklearn pod — shows HTTP requests hitting this pod
kubectl logs -n kserve-demo \
  -l serving.kserve.io/inferenceservice=sklearn-iris \
  -c istio-proxy --tail=5

# Istio proxy logs from xgboost pod
kubectl logs -n kserve-demo \
  -l serving.kserve.io/inferenceservice=xgboost-iris \
  -c istio-proxy --tail=5
```

### Cleanup port-forwards when done

```bash
pkill -f "port-forward.*kserve-demo"
```

---

## Useful kubectl Commands

```bash
# See all 3 InferenceServices
kubectl get inferenceservice -n kserve-demo

# Watch model pods in real-time (great for demos!)
kubectl get pods -n kserve-demo -w

# Check logs for sklearn model
kubectl logs -n kserve-demo -l serving.kserve.io/inferenceservice=sklearn-iris -c kserve-container --tail=50

# Check logs for xgboost model
kubectl logs -n kserve-demo -l serving.kserve.io/inferenceservice=xgboost-iris -c kserve-container --tail=50

# See the full InferenceService status
kubectl describe inferenceservice sklearn-iris -n kserve-demo
kubectl describe inferenceservice xgboost-iris -n kserve-demo
kubectl describe inferenceservice sklearn-iris-canary -n kserve-demo

# Check what's running across all namespaces
kubectl get pods --all-namespaces

# See cluster resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `eksctl` hangs during cluster creation | Normal — EKS takes 15-20 minutes |
| Model stuck in "Unknown" state | Wait 2-3 minutes for the container to pull |
| `curl` returns 404 | Check the model name in the URL matches the InferenceService name |
| `curl` connection refused | Make sure port-forward is still running |
| `ServerlessModeRejected` | Run step 4 again — it patches KServe to RawDeployment mode |
| Pods in `CrashLoopBackOff` | Check logs: `kubectl logs <pod-name> -n kserve-demo` |
| Out of resources | Our t3.medium nodes only have 4GB RAM each — keep resource requests small |
| CRD annotation too long | Use `kubectl apply --server-side --force-conflicts` (already in our script) |

---

## Cost Summary

| Running | Cost |
|---------|------|
| Per hour | ~$0.18 |
| Per day | ~$4.40 |
| Full lab (30 min) | ~$0.10 |

**The cheapest option:** Run the lab in 30 minutes, then immediately cleanup. Total cost: about **10 cents**.

---

## What's Next?

After this lab, explore:
- **02-triton-lab/** — Serve models with NVIDIA Triton Inference Server
- **04-ray-kuberay-lab/** — Ray on Kubernetes via KubeRay (`RayCluster`)

---

## 🏗️ Deep Dive: Every Resource Deployed (Interview-Ready!)

> Run `kubectl get pods --all-namespaces` to see all of this yourself.

### Layer 1: The Cluster (AWS EKS)

```
kubectl get nodes -o wide
```

| Resource | What It Is | Interview Answer |
|----------|-----------|-----------------|
| **EKS Control Plane** | AWS manages the Kubernetes API server, etcd, scheduler, controller-manager. You never see these pods — AWS runs them for you. | "EKS is a managed Kubernetes service. AWS handles the control plane — we only manage worker nodes." |
| **Node 1** (`ip-192-168-29-120`) | A `t3.medium` EC2 instance (2 vCPU, 4GB RAM) running as a Kubernetes worker. Our pods run here. | "Worker nodes are the machines that actually run our containers." |
| **Node 2** (`ip-192-168-42-79`) | Second `t3.medium` — Kubernetes spreads pods across both nodes for reliability. | "Multiple nodes give us high availability. If one node dies, pods restart on the other." |

---

### Layer 2: kube-system (Kubernetes Core — pre-installed)

```
kubectl get pods -n kube-system
```

| Pod | What It Does | Interview Answer |
|-----|-------------|-----------------|
| **coredns** (x2) | DNS server inside the cluster. When a pod calls `sklearn-iris-predictor`, CoreDNS resolves it to the Service IP `10.100.123.222`. | "CoreDNS is the DNS service in Kubernetes. It lets pods find each other by name instead of IP addresses." |
| **kube-proxy** (x2) | Runs on every node. Manages iptables rules so that when traffic hits a Service IP, it gets forwarded to the right pod. | "kube-proxy implements Services. It programs network rules on each node to route Service traffic to the correct pods." |
| **aws-node** (x2) | AWS VPC CNI plugin. Gives each pod a real VPC IP address (not NAT). That's why pods can talk to AWS services directly. | "The CNI plugin assigns IP addresses to pods. AWS VPC CNI gives pods real VPC IPs for native networking." |
| **metrics-server** (x2) | Collects CPU/memory metrics from every pod. The HPA (auto-scaler) reads from this to decide scaling. | "Metrics server provides resource utilization data. HPA uses this to auto-scale deployments." |

---

### Layer 3: cert-manager (TLS Certificates)

```
kubectl get pods -n cert-manager
```

| Pod | What It Does | Interview Answer |
|-----|-------------|-----------------|
| **cert-manager** | Watches for Certificate resources and issues TLS certs. KServe's webhooks need HTTPS — cert-manager creates the certs automatically. | "cert-manager automates TLS certificate issuance and renewal in Kubernetes. It's needed because admission webhooks require HTTPS." |
| **cert-manager-cainjector** | Injects CA (Certificate Authority) bundles into webhook configurations so they can validate the certs. | "The CA injector ensures webhooks trust the certificates by injecting the CA bundle into their configuration." |
| **cert-manager-webhook** | Validates Certificate and Issuer resources before they're created (admission webhook). | "This is cert-manager's own admission webhook — it validates certificate requests before they're processed." |

**How they connect:**
```
You create InferenceService YAML
        ↓
KServe webhook validates it (needs HTTPS)
        ↓
cert-manager issued the TLS cert for that webhook
        ↓
cainjector put the CA bundle in the webhook config
```

---

### Layer 4: Istio Service Mesh (Networking)

```
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress
```

| Pod | Namespace | What It Does | Interview Answer |
|-----|-----------|-------------|-----------------|
| **istiod** | istio-system | The Istio control plane ("pilot"). It configures all the Envoy sidecar proxies in every pod. When a new pod starts, istiod tells its sidecar how to route traffic. | "Istiod is Istio's control plane. It manages configuration for all Envoy sidecar proxies across the mesh." |
| **istio-ingress** | istio-ingress | The ingress gateway — a LoadBalancer Service with an external AWS ELB. This is the "front door" for traffic entering the cluster from the internet. | "The Istio Ingress Gateway is the entry point for external traffic. It's backed by an AWS ELB (Elastic Load Balancer)." |

**Why each model pod shows `2/2 READY` (not `1/1`):**
```
Every pod in kserve-demo has 2 containers:
  Container 1: kserve-container  → The actual model server (sklearn/xgboost)
  Container 2: istio-proxy       → Envoy sidecar (handles networking, metrics, mTLS)
```

**Interview question:** *"Why do KServe pods show 2/2?"*
**Answer:** "Because Istio injects an Envoy sidecar proxy into every pod. So each model pod runs 2 containers — the model server and the Istio proxy. The proxy handles traffic routing, observability, and mutual TLS."

---

### Layer 5: KServe (The ML Platform)

```
kubectl get pods -n kserve
```

| Pod | What It Does | Interview Answer |
|-----|-------------|-----------------|
| **kserve-controller-manager** (2/2) | The brain of KServe. Watches for `InferenceService` resources. When you create one, this controller creates the Deployment, Service, HPA, etc. automatically. Has 2 containers: the controller + kube-rbac-proxy. | "The KServe controller implements the operator pattern. It watches InferenceService custom resources and reconciles them into Deployments, Services, and HPAs." |
| **kserve-localmodel-controller-manager** | Manages local model caching — pre-downloads models to nodes so pods start faster. | "This optimizes cold starts by caching model artifacts on local nodes." |

**What the controller creates when you apply ONE InferenceService YAML:**

```
You apply:  sklearn-iris-inferenceservice.yaml (10 lines of YAML)
                            ↓
KServe controller AUTOMATICALLY creates:
  ├── Deployment         (manages the pod lifecycle)
  ├── Pod                (runs the model server container + istio sidecar)
  ├── Service            (ClusterIP, gives the pod a stable network address)
  ├── HPA                (Horizontal Pod Autoscaler — scales pods by CPU)
  └── [optional] VirtualService, DestinationRule (if using Istio routing)
```

**Interview question:** *"What happens when you apply an InferenceService?"*
**Answer:** "The KServe controller sees the new InferenceService resource, downloads the model from the storageUri using an init container, creates a Deployment with the appropriate model server image (sklearn, xgboost, etc.), creates a ClusterIP Service, and sets up an HPA for auto-scaling."

---

### Layer 6: Your Models (kserve-demo namespace)

```
kubectl get all -n kserve-demo
```

| Resource | Name | What It Is |
|----------|------|-----------|
| **Pod** | `sklearn-iris-predictor-6b64d78479-kmjlx` | Running container with sklearn model server + Istio sidecar |
| **Pod** | `xgboost-iris-predictor-644989f586-fr4r6` | Running container with xgboost model server + Istio sidecar |
| **Pod** | `sklearn-iris-canary-predictor-dcd97db77-lbjx6` | Running container with canary sklearn model + Istio sidecar |
| **Deployment** | `sklearn-iris-predictor` | Manages the sklearn pod — if it crashes, Deployment restarts it |
| **Deployment** | `xgboost-iris-predictor` | Manages the xgboost pod |
| **Deployment** | `sklearn-iris-canary-predictor` | Manages the canary pod |
| **Service** | `sklearn-iris-predictor` (ClusterIP `10.100.123.222`) | Stable network address for the sklearn pod |
| **Service** | `xgboost-iris-predictor` (ClusterIP `10.100.108.191`) | Stable network address for the xgboost pod |
| **Service** | `sklearn-iris-canary-predictor` (ClusterIP `10.100.38.6`) | Stable network address for the canary pod |
| **HPA** | `sklearn-iris-predictor` | Auto-scales: if CPU > 80%, add more pods (currently at 3%) |
| **HPA** | `xgboost-iris-predictor` | Auto-scales the xgboost pods |
| **HPA** | `sklearn-iris-canary-predictor` | Auto-scales the canary pods |
| **InferenceService** | `sklearn-iris` | The KServe custom resource — the ONE YAML you wrote |
| **InferenceService** | `xgboost-iris` | The KServe custom resource for xgboost |
| **InferenceService** | `sklearn-iris-canary` | The KServe custom resource for canary |

---

### Layer 7: Cluster Serving Runtimes (pre-installed model servers)

```
kubectl get clusterservingruntimes
```

These are the **model server images** KServe knows how to use:

| Runtime | Model Format | What It Runs |
|---------|-------------|-------------|
| **kserve-sklearnserver** | sklearn | Scikit-learn models (.pkl, .joblib) |
| **kserve-xgbserver** | xgboost | XGBoost models (.bst, .json) |
| **kserve-tensorflow-serving** | tensorflow | TensorFlow SavedModel format |
| **kserve-torchserve** | pytorch | PyTorch models (.mar files) |
| **kserve-tritonserver** | tensorrt | NVIDIA Triton (multi-framework) |
| **kserve-huggingfaceserver** | huggingface | HuggingFace transformers (LLMs!) |
| **kserve-lgbserver** | lightgbm | LightGBM models |
| **kserve-mlserver** | sklearn | MLServer (alternative sklearn runtime) |
| **kserve-paddleserver** | paddle | PaddlePaddle models |
| **kserve-pmmlserver** | pmml | PMML model format |

**Interview question:** *"How does KServe know which container to use for my model?"*
**Answer:** "You specify `modelFormat.name: sklearn` in your InferenceService YAML. KServe looks up the ClusterServingRuntime with that model type, finds the container image (e.g., `kserve/sklearnserver:v0.14.1`), and uses it to create the pod."

---

### Layer 8: CRDs (Custom Resource Definitions)

```
kubectl get crd | grep serving.kserve.io
```

| CRD | What It Adds to Kubernetes |
|-----|---------------------------|
| **inferenceservices** | The main one! Lets you write `kind: InferenceService` in YAML |
| **clusterservingruntimes** | Defines which container images serve which model formats |
| **servingruntimes** | Same as above but namespace-scoped |
| **trainedmodels** | For model-mesh (multiple models in one server) |
| **inferencegraphs** | Chain multiple models together (pipeline) |
| **clusterstoragecontainers** | Configure how models are downloaded from storage |
| **localmodelcaches** | Pre-cache models on nodes for faster cold starts |

**Interview question:** *"What is a CRD?"*
**Answer:** "A Custom Resource Definition extends the Kubernetes API. Before KServe installed its CRDs, Kubernetes didn't know what an `InferenceService` was. After installing the CRD, you can create InferenceService objects just like you create Deployments or Services — kubectl understands them natively."

---

### 🗺️ The Complete Picture (How Everything Connects)

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        AWS EKS CLUSTER                                   │
│                                                                          │
│  ┌─── kube-system ──────────────────────────────────────────────────┐    │
│  │  coredns (DNS)  │  kube-proxy (routing)  │  aws-node (networking)│    │
│  │  metrics-server (CPU/memory data for HPA)                        │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─── cert-manager ────┐  ┌─── istio-system ───┐  ┌─── istio-ingress ─┐│
│  │ cert-manager        │  │ istiod              │  │ istio-ingress     ││
│  │ cainjector          │  │ (configures proxies)│  │ (AWS ELB front    ││
│  │ webhook             │  │                     │  │  door)            ││
│  │ (TLS certs for      │  └─────────┬───────────┘  └──────────────────┘│
│  │  KServe webhooks)   │            │                                    │
│  └─────────────────────┘            │ configures sidecars                │
│                                     ↓                                    │
│  ┌─── kserve ──────────────────────────────────────────────────────┐    │
│  │ kserve-controller-manager                                       │    │
│  │   "watches InferenceService resources"                          │    │
│  │   "creates Deployments, Services, HPAs automatically"           │    │
│  └─────────────┬───────────────────────────────────────────────────┘    │
│                │ creates ↓                                               │
│  ┌─── kserve-demo ─────────────────────────────────────────────────┐    │
│  │                                                                  │    │
│  │  InferenceService: sklearn-iris                                  │    │
│  │    → Deployment: sklearn-iris-predictor                          │    │
│  │      → Pod [kserve-container + istio-proxy]                     │    │
│  │    → Service: sklearn-iris-predictor (ClusterIP: 10.100.123.222)│    │
│  │    → HPA: scales on CPU > 80%                                   │    │
│  │                                                                  │    │
│  │  InferenceService: xgboost-iris                                  │    │
│  │    → Deployment: xgboost-iris-predictor                          │    │
│  │      → Pod [kserve-container + istio-proxy]                     │    │
│  │    → Service: xgboost-iris-predictor (ClusterIP: 10.100.108.191)│    │
│  │    → HPA: scales on CPU > 80%                                   │    │
│  │                                                                  │    │
│  │  InferenceService: sklearn-iris-canary                           │    │
│  │    → Deployment: sklearn-iris-canary-predictor                   │    │
│  │      → Pod [kserve-container + istio-proxy]                     │    │
│  │    → Service: sklearn-iris-canary-predictor (ClusterIP: 10.100.38.6)│ │
│  │    → HPA: scales on CPU > 80%                                   │    │
│  │                                                                  │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Node 1: ip-192-168-29-120 (t3.medium)                                  │
│  Node 2: ip-192-168-42-79  (t3.medium)                                  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

### 🎯 Top 10 Interview Questions & Answers

1. **Q: What is KServe?**
   A: "KServe is a Kubernetes-native platform for serving ML models. You write one YAML file (InferenceService), and KServe automatically creates the Deployment, Service, and autoscaler."

2. **Q: What does the KServe controller do?**
   A: "It implements the operator pattern — watches for InferenceService resources and reconciles them into Kubernetes primitives like Deployments, Services, and HPAs."

3. **Q: Why does each model pod show 2/2 containers?**
   A: "Istio injects an Envoy sidecar proxy into every pod. Container 1 is the model server, Container 2 is the Istio proxy for traffic management and observability."

4. **Q: What is a CRD?**
   A: "Custom Resource Definition — it extends the Kubernetes API with new resource types. KServe's CRD adds `InferenceService` as a first-class Kubernetes resource."

5. **Q: How does KServe know which container image to use?**
   A: "ClusterServingRuntimes map model formats to container images. When you say `modelFormat: sklearn`, KServe finds the `kserve-sklearnserver` runtime and uses its Docker image."

6. **Q: How does auto-scaling work?**
   A: "KServe creates an HPA (Horizontal Pod Autoscaler) for each model. The HPA watches CPU usage via metrics-server. When CPU exceeds 80%, it adds more pod replicas."

7. **Q: What is cert-manager used for?**
   A: "KServe uses admission webhooks to validate InferenceService resources. Webhooks require HTTPS, so cert-manager automatically creates and renews the TLS certificates."

8. **Q: What's the difference between Serverless and RawDeployment mode?**
   A: "Serverless mode uses Knative and can scale to zero. RawDeployment mode uses plain Kubernetes Deployments — simpler, no Knative dependency, but no scale-to-zero."

9. **Q: How is traffic routed to the correct model?**
   A: "Each model gets its own Kubernetes Service with a unique ClusterIP. Traffic to that Service is forwarded only to pods matching the model's label selector."

10. **Q: What happens inside the pod when a prediction request arrives?**
    A: "The request hits the Istio sidecar first (Container 2), which forwards it to the model server (Container 1). The model server loads the model, runs inference, and returns the prediction."

---

### 📋 kubectl Commands to Show Each Layer

```bash
# Show everything at once
kubectl get all --all-namespaces

# Layer by layer:
kubectl get nodes -o wide                        # The machines
kubectl get pods -n kube-system                   # K8s core
kubectl get pods -n cert-manager                  # TLS certs
kubectl get pods -n istio-system                  # Istio control plane
kubectl get pods -n istio-ingress                 # Istio gateway
kubectl get pods -n kserve                        # KServe controller
kubectl get pods -n kserve-demo                   # YOUR models!
kubectl get inferenceservice -n kserve-demo       # The KServe resources
kubectl get clusterservingruntimes                # Available model servers
kubectl get hpa -n kserve-demo                    # Auto-scalers
kubectl get svc -n kserve-demo                    # Services (network addresses)
kubectl get crd | grep kserve                     # Custom Resource Definitions
```
