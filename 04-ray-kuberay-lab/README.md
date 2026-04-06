# Lab 4: Ray + KubeRay on Kubernetes (EKS)

> **What you build:** A **Ray** cluster on **EKS** managed by the **KubeRay operator** (`RayCluster` CRD): head node, **Ray Dashboard**, and a minimal **`@ray.remote`** task.  
> **Time:** ~20–40 min first run (EKS + Helm + `rayproject/ray` image pull).  
> **Cost:** Same ballpark as other labs (~\$0.20/hr on 2× t3.medium + EKS control plane) — **delete resources when done.**

---

## In plain English: benefits, why we use this, and what happens in real time

### What’s the point? (Benefits you can explain to anyone)

Imagine you have **lots of Python work**—train many models, score millions of rows, run hundreds of simulations. On **one laptop** it takes forever. On **many machines**, someone has to decide: which script runs where, how they talk to each other, what happens when a machine dies.

**Ray** is like hiring a **smart coordinator** for your Python code: you mark functions as “run this somewhere in the cluster,” and Ray **schedules** them, **moves data** when needed, and **tracks** what ran. You think in **Python**, not in “Pod A talks to Pod B on port X.”

**Kubernetes** is great at **running containers** and **restarting** them, but it does **not** know what a “Ray task” is. **KubeRay** is the **bridge**: you write a small YAML that says “I want a Ray cluster shaped like this,” and a **controller (operator)** keeps creating/updating **real Pods** until the cluster matches what you asked for.

**So the benefit in one breath:**  
*You get **distributed Python** (Ray) **on** the same **Kubernetes** your company already uses (EKS), **without** hand-drawing every head/worker Pod and Service yourself (KubeRay).*

### Why not “just more Kubernetes Jobs”?

You *can* run one-off Jobs. For **many small tasks**, **pipelines**, **actors** (stateful workers), and **shared objects** between steps, you end up reinventing a scheduler. Ray gives you that layer; KubeRay **installs** that layer **as** Pods on K8s.

### What happens in real time when you run this lab? (Story order)

Think of it as **three acts** on the same EKS cluster.

**Act 1 — You install the “Ray on K8s” brain (`./02-install-kuberay.sh`)**

- Helm installs the **KubeRay operator** into namespace **`kuberay-system`**.
- That operator **registers** with the API server: “Whenever someone creates a **`RayCluster`** object, I know what to do.”
- **Real time:** Pods for the **operator** start; until they’re healthy, applying a `RayCluster` won’t work. The script waits for the operator’s Deployment to be **Available**.

**Act 2 — You ask for a Ray cluster (`./03-deploy-ray-cluster.sh`)**

- You apply **`namespace.yaml`** → namespace **`ray-lab`** exists.
- You apply **`ray-cluster.yaml`** → one object appears: **`RayCluster/ray-lab-mini`**.
- **In the background (this is the “movie”):** the operator **watches** that object, then creates:
  - a **head Pod** (runs `ray start` as head: GCS, scheduler, **dashboard** port 8265, client port 10001),
  - a **Service** so other Pods (or **port-forward** from your laptop) can reach the head,
  - worker machinery with **0 workers** in this lab (to save RAM on small nodes).
- **Real time:** you’ll see **Pending** → **ContainerCreating** (pulling **`rayproject/ray:2.9.0`**) → **Running** → eventually **Ready** when the container’s health checks pass. **`./03-watch-ray-live.sh`** streams the head pod **logs** so students see Ray actually starting.
- When the head is **Ready**, Ray is **listening inside the cluster**—but your laptop can’t see it until you **port-forward**.

**Act 3 — You prove it works (`./05-test-ray-remote.sh` + optional `./04-port-forward-dashboard.sh`)**

- The script finds the **head Pod** by label **`ray.io/node-type=head`**.
- It **copies** `examples/hello_ray.py` **into** the pod (via stdin + `cat`, not `kubectl cp`, for Windows friendliness).
- It runs **`python /tmp/hello_ray.py`** **inside** that pod. The script does **`ray.init(address="auto")`** so your Python **joins** the Ray cluster already running in that container, then runs a tiny **`@ray.remote`** function.
- **Real time:** you should see printed text like **`hello-from-ray-remote`** and **`cluster_resources`** — that’s proof the **Ray runtime** accepted work and ran it.
- **Dashboard (`./04-port-forward-dashboard.sh`):** your laptop opens **localhost:8265** → Kubernetes forwards TCP to **`ray-lab-mini-head-svc:8265`** → you see the **live** Ray UI (nodes, resources). That’s “real time” in the sense of a **running system**, not a batch log file only.

### What students should *feel* after reading this

- **Before:** “Distributed = scary networking and many YAML files.”  
- **After:** “I declare **one** `RayCluster`, the **operator** materializes Pods, Ray **runs inside** them, and I can **see** it in logs, **dashboard**, and a **5-line** Python script.”

---

## What problem does this solve? (Short recap)

- **Ray** gives you **distributed Python** (tasks, actors, object store) without hand-wiring every Pod yourself.
- **KubeRay** runs **Ray on Kubernetes**: you declare a **`RayCluster`**, the **operator** creates **Pods** and **Services** (head, workers, dashboard).

**Analogy:** Kubernetes schedules **containers**; Ray schedules **Python work** across those containers. KubeRay connects the two.

---

## What this lab is / is not

| In scope | Out of scope (mention as “next”) |
|----------|----------------------------------|
| Helm install **kuberay-operator** | GPU node pools, autoscaling production tuning |
| **`RayCluster`** head + **workers: 0** (minimal RAM) | Ray Serve HTTP deployment (separate lesson) |
| **Dashboard** (`port-forward` :8265) | Ingress / TLS / multi-tenancy |
| **`kubectl exec`** + **`hello_ray.py`** | Ray Jobs CLI from laptop |

**Pinned versions (classroom stability):** Ray **2.9.0** image, KubeRay Helm **1.1.0** (override with `KUBERAY_HELM_VERSION`).

---

## Layout

```
04-ray-kuberay-lab/
├── examples/
│   └── hello_ray.py              # @ray.remote demo (copied into head pod)
├── manifests/
│   ├── eks-cluster.yaml          # eksctl — cluster ray-kuberay-lab
│   ├── namespace.yaml            # ray-lab
│   └── ray-cluster.yaml          # RayCluster ray-lab-mini
└── scripts/
    ├── 00-prerequisites-check.sh
    ├── 01-create-eks-cluster.sh
    ├── 02-install-kuberay.sh     # Helm: kuberay-operator → kuberay-system
    ├── 03-deploy-ray-cluster.sh
    ├── 03-watch-ray-live.sh        # kubectl logs -f head pod
    ├── 04-port-forward-dashboard.sh
    ├── 05-test-ray-remote.sh
    ├── 06-cleanup-lab.sh           # delete RayCluster + namespace ray-lab
    ├── 07-uninstall-kuberay-operator.sh
    ├── 08-delete-eks-cluster.sh
    ├── apply-ray-manifests.sh
    └── run-all.sh
```

---

## Quick start

```bash
cd 04-ray-kuberay-lab/scripts
chmod +x *.sh

# If you need a dedicated cluster:
./01-create-eks-cluster.sh

./00-prerequisites-check.sh
./02-install-kuberay.sh
./03-deploy-ray-cluster.sh
./05-test-ray-remote.sh

# Optional — second terminal:
./04-port-forward-dashboard.sh   # http://127.0.0.1:8265
```

One-shot (cluster + context already exist):

```bash
./run-all.sh
```

---

## Important objects (teaching checklist)

| Object | Name | Namespace |
|--------|------|-----------|
| Helm release | `kuberay-operator` | `kuberay-system` |
| **RayCluster** | `ray-lab-mini` | `ray-lab` |
| Head **Service** (dashboard) | `ray-lab-mini-head-svc` | `ray-lab` |
| Head **Pod** label | `ray.io/node-type=head` | `ray-lab` |

---

## Flow: `./02-install-kuberay.sh`

1. `helm repo add` / `helm repo update` **kuberay** charts.
2. `helm upgrade --install kuberay-operator kuberay/kuberay-operator -n kuberay-system --create-namespace --version 1.1.0 --wait`.
3. Waits for the **first Deployment** in `kuberay-system` to roll out.
4. Installs **CRDs** (including `ray.io/v1` **RayCluster**) if not already present.

---

## Flow: `./03-deploy-ray-cluster.sh`

1. `kubectl apply` **`namespace.yaml`** → **`ray-lab`**.
2. `kubectl apply` **`ray-cluster.yaml`** → **KubeRay** reconciles: creates **head Pod**, **Service** `ray-lab-mini-head-svc`, **worker** ReplicaSet (0 replicas).
3. Waits until a **head** pod exists and `kubectl wait --for=condition=Ready pod -l ray.io/node-type=head -n ray-lab`.

---

## Flow: `./05-test-ray-remote.sh`

1. Sets **`MSYS_NO_PATHCONV=1`** on Windows/Git Bash so `/tmp` is not rewritten to a Windows path.
2. Resolves head pod name via **`ray.io/node-type=head`**.
3. Pipes **`examples/hello_ray.py`** into the pod: **`kubectl exec -i … sh -c 'cat > /tmp/hello_ray.py'`** (avoids broken **`kubectl cp`** on Windows).
4. Runs **`kubectl exec … sh -c 'python /tmp/hello_ray.py'`** → **`ray.init(address="auto")`** + **`@ray.remote`** task → prints **`hello-from-ray-remote`** and **`cluster_resources`**.

---

## Scaling workers (optional demo)

Edit **`manifests/ray-cluster.yaml`**: under **`workerGroupSpecs`**, set **`replicas: 1`** (or more), then:

```bash
./apply-ray-manifests.sh
kubectl get pods -n ray-lab -w
```

Ensure nodes have enough **CPU/RAM** for head + workers.

---

## Cleanup

| Script | Effect |
|--------|--------|
| **`06-cleanup-lab.sh`** | Deletes **RayCluster** + **`ray-lab`** namespace |
| **`07-uninstall-kuberay-operator.sh`** | `helm uninstall` + removes **`kuberay-system`** |
| **`08-delete-eks-cluster.sh`** | Destroys **ray-kuberay-lab** EKS cluster |

---

## Troubleshooting

| Symptom | Check |
|---------|--------|
| `no matches for kind "RayCluster"` | Operator not installed — run **`02-install-kuberay.sh`** |
| Head pod **Pending** | `kubectl describe pod -n ray-lab` — CPU/memory vs node capacity |
| **`hello_ray.py`** connection errors | Head not fully up; try `ray.init(address="ray://127.0.0.1:10001")` inside pod if `auto` fails |
| Wrong **Helm** version | Set `KUBERAY_HELM_VERSION` to a version listed in [kuberay-helm](https://github.com/ray-project/kuberay-helm) |
| `kubectl cp` — *one of src or dest must be a local file specification* (Windows/Git Bash) | **`05-test-ray-remote.sh`** pipes the file with `kubectl exec … -i … sh -c 'cat > /tmp/hello_ray.py'` instead of `kubectl cp`. |
| `python: can't open file 'C:/Users/.../Temp/hello_ray.py'` | **Git Bash** rewrites `/tmp/...` into your Windows Temp path before `kubectl exec` sees it. The script sets **`MSYS_NO_PATHCONV=1`** and runs **`sh -c 'python /tmp/hello_ray.py'`** so the container sees a real Linux `/tmp` path. |

---

## References

- [KubeRay — Getting started](https://docs.ray.io/en/latest/cluster/kubernetes/getting-started.html)  
- [RayCluster CRD](https://docs.ray.io/en/latest/cluster/kubernetes/user-guides/config.html)  
- [KubeRay GitHub](https://github.com/ray-project/kuberay)
