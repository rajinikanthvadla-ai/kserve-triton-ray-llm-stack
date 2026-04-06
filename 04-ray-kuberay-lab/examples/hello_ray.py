#!/usr/bin/env python3
"""Minimal Ray task — run inside the Ray head pod (cluster already running)."""
import ray

ray.init(address="auto")

@ray.remote
def hello() -> str:
    return "hello-from-ray-remote"


if __name__ == "__main__":
    out = ray.get(hello.remote())
    print(out)
    print("cluster_resources:", ray.cluster_resources())
