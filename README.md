# KServe + Triton + Ray — ML Serving Stack (Hands-on Labs)

> Real-world, hands-on labs for deploying ML models at scale using KServe, NVIDIA Triton, vLLM, and Ray (KubeRay) on Kubernetes.

---

## Labs Overview

| Lab | What | Status |
|-----|------|--------|
| [01-kserve-lab](./01-kserve-lab/) | Deploy ML models on EKS with KServe (sklearn + xgboost) | ✅ Ready |
| [02-triton-lab](./02-triton-lab/) | Serve ONNX models with NVIDIA Triton (Iris + Sentiment NLP) | ✅ Ready |
| [03-vllm-cpu-lab](./03-vllm-cpu-lab/) | Run **vLLM** (OpenAI API) on **CPU**; includes **eksctl** create/delete + live log demo | ✅ Ready |
| [04-ray-kuberay-lab](./04-ray-kuberay-lab/) | **Ray** on EKS via **KubeRay** (`RayCluster`), Dashboard + `@ray.remote` test | ✅ Ready |

---

## Start Here

```bash
# Go to the KServe lab
cd 01-kserve-lab/scripts

# Make scripts executable
chmod +x *.sh

# Option A: Run everything automatically (~30 min)
./run-all.sh

# Option B: Run step by step (recommended)
./00-prerequisites-check.sh
./01-create-eks-cluster.sh
./02-install-cert-manager.sh
./03-install-istio.sh
./04-install-kserve.sh
./05-deploy-model.sh
./06-test-inference.sh

# When done — DELETE THE CLUSTER to save money!
./07-cleanup.sh
```

---

## Prerequisites

- AWS account with credentials configured (`aws configure`)
- Tools: `aws`, `eksctl`, `kubectl`, `helm`, `curl`, `jq`
- Bash shell (Linux/Mac/WSL)

---

## Cost

Each lab uses minimal resources to save money:
- **EKS cluster:** 2x t3.medium nodes (~$0.18/hr)
- **Full lab run:** ~$0.10 (30 minutes)
- **⚠️ Always cleanup when done!**
