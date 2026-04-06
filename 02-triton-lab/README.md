# Lab 2: Triton Inference Server on KServe

> **What you'll build:** Deploy ONNX models (Iris classifier + Sentiment analysis) using NVIDIA Triton Inference Server through KServe.  
> **Time:** ~15 minutes | **Cost:** Same cluster as Lab 1 | **Prerequisite:** Lab 1 completed (cluster running)

---

## What is Triton Inference Server?

Triton is **NVIDIA's model serving engine**. Think of it as the "Formula 1 car" of model servers:

```
Lab 1: sklearn-server  →  Like a bicycle (simple, gets the job done)
Lab 2: Triton server   →  Like a Formula 1 car (fast, optimized, production-grade)
```

**Why companies use Triton:**
- **ONNX Runtime** — runs models 2-5x faster than native sklearn/pytorch
- **Dynamic Batching** — combines multiple requests into one GPU/CPU call
- **Multi-Model** — serve many models in a single server process
- **Prometheus Metrics** — built-in monitoring for production dashboards
- **V2 Protocol** — industry-standard inference API (KServe open inference protocol)

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        EKS Cluster (from Lab 1)                  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    KServe Controller                        │ │
│  │  "Same controller as Lab 1, but now using Triton runtime"  │ │
│  └─────────────┬───────────────────────────┬───────────────────┘ │
│                │                           │                     │
│  ┌─────────────▼──────────┐  ┌─────────────▼──────────────────┐  │
│  │  Pod: iris-triton      │  │  Pod: sentiment-triton         │  │
│  │  ┌──────────────────┐  │  │  ┌──────────────────────────┐  │  │
│  │  │ Triton Server    │  │  │  │ Triton Server            │  │  │
│  │  │ (ONNX Runtime)   │  │  │  │ (ONNX Runtime)           │  │  │
│  │  │                  │  │  │  │                          │  │  │
│  │  │ Model: iris.onnx │  │  │  │ Model: distilbert.onnx   │  │  │
│  │  │ Input: 4 floats  │  │  │  │ Input: token IDs         │  │  │
│  │  │ Output: class    │  │  │  │ Output: pos/neg logits   │  │  │
│  │  └──────────────────┘  │  │  └──────────────────────────┘  │  │
│  │  ┌──────────────────┐  │  │  ┌──────────────────────────┐  │  │
│  │  │ Istio sidecar    │  │  │  │ Istio sidecar            │  │  │
│  │  └──────────────────┘  │  │  └──────────────────────────┘  │  │
│  └────────────────────────┘  └────────────────────────────────┘  │
│                                                                  │
│  Models stored in:  S3 bucket (your AWS account)                │
└──────────────────────────────────────────────────────────────────┘

Sentiment analysis full pipeline:
  ┌──────────┐    ┌───────────────┐    ┌────────────────┐
  │ Raw text │    │ Your backend  │    │ Triton Server  │
  │ "Great!" │───▶│ tokenizes →   │───▶│ runs ONNX      │──▶ POSITIVE 99%
  └──────────┘    │ [101,2307,..]│    │ returns logits │
                  └───────────────┘    └────────────────┘
```

---

## Lab 1 vs Lab 2 Comparison

| | Lab 1 (KServe + sklearn) | Lab 2 (KServe + Triton) |
|---|---|---|
| **Runtime** | `kserve-sklearnserver` | `kserve-tritonserver` |
| **Model format** | .pkl (pickle) | .onnx (ONNX) |
| **API protocol** | V1 (`/v1/models/X:predict`) | V2 (`/v2/models/X/infer`) |
| **Batching** | None | Dynamic batching ✅ |
| **Metrics** | None | Prometheus metrics ✅ |
| **Model metadata API** | Basic | Full (input/output shapes) ✅ |
| **GPU support** | ❌ | ✅ CUDA, TensorRT |
| **Model types** | sklearn only | ONNX, TensorFlow, PyTorch, TensorRT |

---

## Project Structure

```
02-triton-lab/
├── models/
│   ├── convert-iris-onnx.py            ← Convert sklearn Iris → ONNX
│   ├── convert-sentiment-onnx.py       ← Convert DistilBERT → ONNX
│   └── test-sentiment.py               ← Python test script (tokenize + call Triton)
├── scripts/
│   ├── 00-prepare-models.sh            ← Install deps + convert models
│   ├── 01-setup-s3-and-credentials.sh  ← Create S3 bucket + K8s creds
│   ├── 02-deploy-triton-models.sh      ← Deploy on Triton via KServe
│   ├── 03-test-inference.sh            ← Test both models
│   ├── 04-triton-features.sh           ← Demo: metrics, batching, metadata
│   ├── 05-cleanup.sh                   ← Remove Lab 2 resources
│   └── run-all.sh                      ← Run everything automatically
├── requirements.txt                    ← Python dependencies
└── README.md                          ← You are here!
```

---

## Prerequisites

- **Lab 1 cluster must be running** (EKS + KServe + Istio)
- **Python 3.8+** with pip
- **AWS CLI** configured (`aws configure`)

---

## Quick Start

```bash
cd 02-triton-lab/scripts
chmod +x *.sh
./run-all.sh
```

---

## Step-by-Step Guide

### Step 0: Prepare Models (~3-5 min)

```bash
./00-prepare-models.sh
```

**What it does:**
1. Installs Python deps (transformers, onnx, torch, etc.)
2. Trains Iris classifier → converts to ONNX
3. Downloads DistilBERT sentiment model → converts to ONNX
4. Creates Triton model repository structure

**From my experience:** ONNX (Open Neural Network Exchange) is a universal model format. You can train in PyTorch, export to ONNX, and serve with Triton — no framework lock-in!

---

### Step 1: Upload to S3 + Setup Credentials (~1-2 min)

```bash
./01-setup-s3-and-credentials.sh
```

**What it does:**
1. Creates an S3 bucket in your AWS account
2. Uploads both ONNX models to S3
3. Creates K8s Secret with AWS credentials
4. Creates ServiceAccount for KServe to access S3

**From my experience:** In production, models are stored in object storage (S3/GCS). KServe downloads models from storage at startup using init containers.

---

### Step 2: Deploy Triton Models (~3-5 min)

```bash
./02-deploy-triton-models.sh
```

**What it does:** Deploys 2 InferenceServices using `kserve-tritonserver` runtime.

**From my experience:** Look at how simple the YAML is — same `InferenceService` as Lab 1, just changed `runtime: kserve-tritonserver` and `modelFormat: onnx`. KServe abstracts the runtime differences!

---

### Step 3: Test Models (~1 min)

```bash
./03-test-inference.sh
```

**What it does:**
- Tests Iris on Triton using V2 protocol (curl)
- Tests Sentiment using Python tokenizer + Triton
- Shows model metadata and health endpoints

---

### Step 4: Triton Features Demo (~1 min)

```bash
./04-triton-features.sh
```

**What it does:** Demonstrates Triton-specific features:
- Server metadata API
- Model metadata (input/output shapes)
- Dynamic batching
- Prometheus metrics
- Health/ready endpoints

---

### Step 5: Cleanup

```bash
./05-cleanup.sh
```

Removes Lab 2 models, S3 bucket, and credentials. Does NOT delete the EKS cluster.

---

## 🧪 Curl Commands — Test Manually

### Setup port-forwards:

```bash
kubectl port-forward svc/iris-triton-predictor -n triton-demo 8084:80 &
kubectl port-forward svc/sentiment-triton-predictor -n triton-demo 8085:80 &
```

### Test Iris on Triton (V2 protocol):

```bash
# Single prediction
curl -s http://localhost:8084/v2/models/iris-onnx/infer \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [{
      "name": "float_input",
      "shape": [1, 4],
      "datatype": "FP32",
      "data": [6.8, 2.8, 4.8, 1.4]
    }]
  }' | jq .

# Batch prediction (3 flowers at once — dynamic batching!)
curl -s http://localhost:8084/v2/models/iris-onnx/infer \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [{
      "name": "float_input",
      "shape": [3, 4],
      "datatype": "FP32",
      "data": [5.1,3.5,1.4,0.2, 6.7,3.0,5.0,1.7, 7.7,3.8,6.7,2.2]
    }]
  }' | jq .
```

### Test Sentiment (Python script):

```bash
cd 02-triton-lab/models
python test-sentiment.py "This product is absolutely amazing!"
python test-sentiment.py "Worst purchase ever. Total waste of money."
python test-sentiment.py "The weather is fine today."
```

### Triton-specific endpoints:

```bash
# Server info
curl -s http://localhost:8084/v2 | jq .

# Model metadata (shows input/output shapes)
curl -s http://localhost:8084/v2/models/iris-onnx | jq .

# Health check
curl -s http://localhost:8084/v2/health/ready

# Prometheus metrics
curl -s http://localhost:8084/metrics
```

### Kill port-forwards:

```bash
pkill -f "port-forward.*triton"
```

---

## V1 vs V2 Inference Protocol

| | V1 (Lab 1) | V2 (Lab 2 — Triton) |
|---|---|---|
| **Endpoint** | `/v1/models/{name}:predict` | `/v2/models/{name}/infer` |
| **Request format** | `{"instances": [[1,2,3,4]]}` | `{"inputs": [{"name":"x","shape":[1,4],"datatype":"FP32","data":[1,2,3,4]}]}` |
| **Response format** | `{"predictions": [1]}` | `{"outputs": [{"name":"y","shape":[1],"datatype":"INT64","data":[1]}]}` |
| **Why V2?** | Simple, easy to use | Explicit shapes/types, batch-friendly, industry standard |
| **Used by** | KServe sklearn/xgboost | Triton, TensorRT, ONNX Runtime |

---

## Triton's config.pbtxt Explained

```protobuf
name: "iris-onnx"                    # Model name (used in URL)
platform: "onnxruntime_onnx"         # Use ONNX Runtime backend

max_batch_size: 8                    # Triton can batch up to 8 requests

input [
  {
    name: "float_input"              # Must match ONNX model's input name
    data_type: TYPE_FP32             # 32-bit float
    dims: [4]                        # 4 features per sample
  }
]

output [
  {
    name: "output_label"             # Predicted class
    data_type: TYPE_INT64
    dims: [1]
  }
]

instance_group [
  {
    count: 1                         # 1 model instance
    kind: KIND_CPU                   # Run on CPU (use KIND_GPU for GPU)
  }
]

dynamic_batching {                   # TRITON SPECIAL FEATURE
  max_queue_delay_microseconds: 100  # Wait up to 100μs to batch requests
}
```

---

## Key Concepts

1. **ONNX** — Open model format. Train anywhere (sklearn, PyTorch, TF), serve everywhere (Triton, ONNX Runtime).
2. **Triton Inference Server** — NVIDIA's production model server. Supports ONNX, TensorFlow, PyTorch, TensorRT.
3. **Dynamic Batching** — Triton automatically combines individual requests into batches for higher throughput.
4. **V2 Protocol** — Industry-standard inference API with explicit input/output shapes and types.
5. **config.pbtxt** — Triton's model configuration file. Defines inputs, outputs, batching, and instance groups.
6. **Model Repository** — Directory structure Triton expects: `model-name/version/model.onnx`.
7. **Prometheus Metrics** — Triton exports inference count, latency, queue time — ready for Grafana dashboards.
8. **StorageUri** — KServe pulls models from S3/GCS at pod startup using init containers.
