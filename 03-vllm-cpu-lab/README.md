# Lab 3: vLLM on CPU (EKS)

> **What you run:** The official [vLLM](https://github.com/vllm-project/vllm) **OpenAI-compatible HTTP server** on **CPU-only** workers, using plain Kubernetes (`Deployment` + `Service`).  
> **Time:** ~15–20 min (EKS) + 20–45 min first vLLM start (image + model download).  
> **Cluster:** This lab includes scripts to **create and delete its own EKS cluster** (`vllm-cpu-lab`), or you can use any existing cluster with `kubectl`. **No KServe or GPUs** required.

---

## What is vLLM?

vLLM is an **LLM inference engine** and server, not a separate “model format” like ONNX. In production people often pair it with Kubernetes gateways or serving layers; here we deploy **vLLM directly** so you see the core moving parts.

| Idea | What it means for you |
|------|------------------------|
| **LLM engine** | Loads a Hugging Face–style model and runs **token generation** (decode loop). |
| **PagedAttention** | Manages **KV cache** in pages so memory is shared efficiently across requests (vLLM’s headline optimization). |
| **Continuous batching** | New requests can join a batch **between steps** instead of only at fixed batch boundaries. |
| **OpenAI-compatible API** | Same JSON routes many tools already speak: `/v1/chat/completions`, `/v1/models`, etc. |
| **CPU backend** | Slower than GPU, but the **same concepts** (scheduler, KV cache, max model length, concurrency limits). |

Official CPU installation and tuning notes: [vLLM CPU docs](https://docs.vllm.ai/en/stable/getting_started/installation/cpu.html).

---

## How this lab differs from Lab 1 / Lab 2

| | Lab 1 (KServe sklearn) | Lab 2 (Triton) | This lab (vLLM CPU) |
|---|------------------------|----------------|----------------------|
| **Workload** | Small ML models | ONNX graphs | **Generative LLM** (autoregressive tokens) |
| **Protocol** | KServe V1 predict | Triton V2 infer | **OpenAI HTTP** (`/v1/...`) |
| **Runtime** | kserve-sklearnserver | Triton | **vLLM** (`vllm.entrypoints.openai.api_server`) |
| **KServe** | Yes | Yes | **No** (minimal K8s only) |

KServe can front custom containers too; this lab skips that so you learn **vLLM first**, then you can add routing, auth, and autoscaling in a later iteration.

---

## Architecture (minimal)

```
┌─────────────────────────────────────────────────────────┐
│  EKS cluster (CPU nodes, e.g. t3.medium)                │
│                                                         │
│  Namespace: vllm-cpu-lab                                │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Pod: vLLM OpenAI server                          │  │
│  │  Image: vllm/vllm-openai-cpu:latest-x86_64        │  │
│  │  Model: SmolLM2-135M-Instruct (HF download @ startup) │  │
│  │  Port: 8000  →  Service: vllm-opt125m             │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  You: kubectl port-forward → curl /v1/chat/completions  │
└─────────────────────────────────────────────────────────┘
```

---

## Project layout

```
03-vllm-cpu-lab/
├── manifests/
│   ├── eks-cluster.yaml       # eksctl — EKS + 2x t3.medium
│   ├── namespace.yaml
│   └── vllm-cpu.yaml          # Deployment + Service
├── scripts/
│   ├── 00-prerequisites-check.sh
│   ├── 01-create-eks-cluster.sh
│   ├── 02-deploy-vllm.sh
│   ├── apply-manifests.sh     # kubectl apply with correct paths (use if you skipped 02)
│   ├── 03-watch-vllm-live.sh  # real-time pod phase + log stream
│   ├── 04-test-chat.sh
│   ├── 05-cleanup-lab.sh      # delete namespace only
│   ├── 06-delete-eks-cluster.sh
│   └── run-all.sh             # deploy + test (no cluster create/delete)
└── README.md
```

---

## Prerequisites

- **AWS:** `aws` + `eksctl` + credentials (`aws configure`)
- **Kubernetes:** `kubectl`
- **HTTP:** `curl`, `jq`
- Nodes with enough RAM for the pod (manifest **limits memory to ~3.8Gi**; **t3.medium** matches the included `eks-cluster.yaml`)
- Outbound HTTPS from workers to **Hugging Face** (model weights download)
- **Hugging Face token:** **not required** for this lab’s default model [`HuggingFaceTB/SmolLM2-135M-Instruct`](https://huggingface.co/HuggingFaceTB/SmolLM2-135M-Instruct) (it is **public**). You only need a token if you switch to a **gated** or **private** model — see [Hugging Face token](#hugging-face-token-do-you-need-it) below.

---

## Hugging Face token: do you need it?

| Situation | Token? |
|-----------|--------|
| Default lab (`HuggingFaceTB/SmolLM2-135M-Instruct` in [`vllm-cpu.yaml`](manifests/vllm-cpu.yaml)) | **No** — public weights download anonymously. |
| You change `--model` to a **gated** model (e.g. Llama family) or a **private** repo | **Yes** — create a token at [Hugging Face → Settings → Access Tokens](https://huggingface.co/settings/tokens) with **read** access. |

**When to do it (only if you need a token):** after the cluster exists and **before** the vLLM pod starts downloading that model — i.e. **after** `./01-create-eks-cluster.sh` (or any step where `kubectl` works), and **before** `./02-deploy-vllm.sh`.

Concrete order:

1. Create the namespace (same as the full deploy, but only this file first):

   ```bash
   kubectl apply -f manifests/namespace.yaml
   ```

2. Create the secret in that namespace (replace `hf_...` with your token):

   ```bash
   kubectl create secret generic huggingface-token \
     -n vllm-cpu-lab \
     --from-literal=token="hf_..."
   ```

3. Edit [`manifests/vllm-cpu.yaml`](manifests/vllm-cpu.yaml): under the container `env:` block, add:

   ```yaml
   - name: HF_TOKEN
     valueFrom:
       secretKeyRef:
         name: huggingface-token
         key: token
   ```

4. Set `--model` in the same file to your gated/private model ID, then run **`./02-deploy-vllm.sh`** as usual.

If the Deployment is already running and you add a token later, **roll out again** after editing the manifest: `kubectl apply -f manifests/vllm-cpu.yaml` and wait for a new pod (or `./05-cleanup-lab.sh` and redeploy).

---

## End-to-end flow (create cluster → see vLLM live → test → tear down)

From the **repository root** (the folder that contains `03-vllm-cpu-lab/`):

```bash
cd 03-vllm-cpu-lab/scripts
chmod +x *.sh

# 1) Create cluster (~15–20 min, ~$0.20/hr while running)
./01-create-eks-cluster.sh

# Optional — only if you use a gated/private HF model (see section above):
#   kubectl apply -f ../manifests/namespace.yaml
#   kubectl create secret generic huggingface-token -n vllm-cpu-lab --from-literal=token="hf_..."
#   (then add HF_TOKEN to vllm-cpu.yaml and change --model)

# 2) Apply vLLM manifests (paths are always correct — do not hand-type kubectl apply from the wrong folder)
./02-deploy-vllm.sh
#    or: ./apply-manifests.sh

# 3) REAL-TIME: watch pod phase + stream container logs (image pull → HF → Uvicorn)
#    Stop with Ctrl+C when logs show the server is listening.
./03-watch-vllm-live.sh

# 4) Proof it works: OpenAI-compatible JSON from inside the cluster
./04-test-chat.sh

# 5) Remove only the vLLM workload (optional; keeps EKS for other tests)
./05-cleanup-lab.sh

# 6) Delete the whole cluster (stops AWS charges)
./06-delete-eks-cluster.sh   # type: yes
```

**Fast path** (cluster already exists):

```bash
./run-all.sh    # deploy + wait for rollout + curl test (skips live watch)
```

### Why `03-watch-vllm-live.sh` matters

vLLM on a fresh node is **not instant**: you should see the **image pull**, **Hugging Face download**, **model load**, then **Uvicorn** listening on port 8000. That script prints **pod phase** until `Running`, shows recent **events**, then **`kubectl logs -f`** so you can show a class or recording that the flow is real.

---

## What to read in the manifest

Open [`manifests/vllm-cpu.yaml`](manifests/vllm-cpu.yaml) and relate each knob to vLLM behavior:

- **`command` / `args`** — Starts the **OpenAI API server** and pins **`--model`**, **`--dtype`**, **`--max-model-len`**, **`--max-num-seqs`** (memory vs throughput tradeoff).
- **`VLLM_CPU_KVCACHE_SPACE`** — KV cache **budget on CPU** (GiB); larger → more concurrent / longer context, but needs RAM headroom. See the [CPU env docs](https://docs.vllm.ai/en/stable/getting_started/installation/cpu.html#related-runtime-environment-variables).
- **`VLLM_CPU_OMP_THREADS_BIND`** — How OpenMP threads map to cores (`auto` is a good default to study first).
- **`/dev/shm`** — Larger shared memory avoids common PyTorch multiprocessing issues in containers.
- **`seccompProfile: Unconfined` + `SYS_NICE`** — Aligns with vLLM’s Docker guidance for **NUMA / scheduling** behavior in containers (optional hardening can replace this in production).

---

## ARM (Graviton) nodes

If your node pool is **arm64**, edit the image in `vllm-cpu.yaml` to:

`vllm/vllm-openai-cpu:latest-arm64`

(Tag list: [Docker Hub — vllm-openai-cpu](https://hub.docker.com/r/vllm/vllm-openai-cpu/tags).)

---

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| `OOMKilled` | Raise node RAM or lower `--max-model-len`, `--max-num-seqs`, or `VLLM_CPU_KVCACHE_SPACE`. |
| Pod stays `Pending` | Not enough CPU/memory on any node; scale node group or relax `resources`. |
| Very long `ContainerCreating` | Large image pull; wait or use image pull on a larger node / mirror. |
| Readiness never passes | Model download blocked or still loading; `kubectl logs -n vllm-cpu-lab deploy/vllm-opt125m-cpu -f`. |
| HF 401 / “gated” / “repository not found” in logs | You picked a **gated** or **private** model without `HF_TOKEN` — follow [Hugging Face token](#hugging-face-token-do-you-need-it). |
| `The model ... does not exist` (404) | The **`model`** in your JSON must match **`id`** from `GET /v1/models` (whatever the server actually loaded). [`04-test-chat.sh`](scripts/04-test-chat.sh) reads it automatically. If you still see **`facebook/opt-125m`** in `/v1/models` but wanted SmolLM2, your **`kubectl apply` never ran** (wrong directory). From `scripts/`: run **`./apply-manifests.sh`**, then **`kubectl rollout restart deployment/vllm-opt125m-cpu -n vllm-cpu-lab`**. |
| `default chat template is no longer allowed` (400 on `/v1/chat/completions`) | **Transformers ≥ 4.44** needs a tokenizer `chat_template`. This lab uses **SmolLM2-135M-Instruct**, which ships one. Do **not** use raw causal-only models like `facebook/opt-125m` for `/v1/chat/completions` unless you patch the tokenizer or pass a template vLLM applies correctly. Re-apply after model changes: `kubectl apply -f manifests/vllm-cpu.yaml && kubectl rollout restart deployment/vllm-opt125m-cpu -n vllm-cpu-lab`. Remove stale ConfigMaps from older drafts: `kubectl delete configmap vllm-chat-template -n vllm-cpu-lab --ignore-not-found`. |

---

## Further reading (to “get” vLLM end to end)

- [PagedAttention design](https://docs.vllm.ai/en/latest/design/paged_attention/) — why KV cache paging matters  
- [Kubernetes deployment (vLLM docs)](https://docs.vllm.ai/en/latest/deployment/k8s.html) — patterns beyond this minimal lab  
- [Server arguments](https://docs.vllm.ai/en/latest/configuration/serve_args/) — every CLI flag maps to behavior you can experiment with in the manifest  
