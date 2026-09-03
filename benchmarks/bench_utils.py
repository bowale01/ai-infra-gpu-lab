"""Shared helpers for the CPU vs GPU benchmarks.

Handles device detection, accurate GPU timing (CUDA is asynchronous, so you must
synchronize before reading the clock), and writing results to JSON in ../results/.
"""
from __future__ import annotations

import json
import os
import platform
import time
from dataclasses import dataclass, asdict
from datetime import datetime, timezone

import torch

RESULTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "results")


def available_devices() -> list[str]:
    """Return the devices to benchmark. Always includes CPU; adds CUDA if present."""
    devices = ["cpu"]
    if torch.cuda.is_available():
        devices.append("cuda")
    return devices


def device_label(device: str) -> str:
    """Human-friendly device name, e.g. 'NVIDIA T4' or the CPU arch."""
    if device == "cuda" and torch.cuda.is_available():
        return torch.cuda.get_device_name(0)
    return platform.processor() or platform.machine() or "CPU"


def synchronize(device: str) -> None:
    """Block until all queued GPU work has actually finished.

    Why this matters: when you call a GPU op in PyTorch, it doesn't run then and there.
    It gets *queued* and control returns to Python immediately, while the GPU works in the
    background (this is what "asynchronous execution" means). So if you start a timer,
    launch a GPU op, and stop the timer, you've measured how long it took to *hand off*
    the work — often microseconds — not how long the GPU took to *do* it.

    Calling torch.cuda.synchronize() forces Python to wait for the GPU to finish, so the
    clock reflects real compute time. On CPU there's nothing to wait for, so this is a
    no-op there.
    """
    if device == "cuda":
        torch.cuda.synchronize()


def time_op(fn, device: str, warmup: int = 3, iters: int = 10) -> float:
    """Time a callable, returning the average seconds per iteration.

    Two details that keep the numbers honest:

    1. Warmup runs (discarded): the first time a GPU op runs, it pays one-time costs —
       CUDA context init, memory allocation, kernel autotuning/caching. Timing those would
       make the GPU look artificially slow, so we run a few throwaway iterations first.

    2. Synchronize before stopping the clock: we let the loop queue all `iters` ops, then
       synchronize once so the elapsed time includes the GPU actually finishing them (see
       synchronize() above). We time the whole batch and divide, which also averages out
       small per-call jitter.
    """
    # Warmup — run and fully complete a few times so caches/allocations are hot.
    for _ in range(warmup):
        fn()
        synchronize(device)

    start = time.perf_counter()
    for _ in range(iters):
        fn()
    synchronize(device)  # wait for the GPU to drain the queue before reading the clock
    elapsed = time.perf_counter() - start
    return elapsed / iters


@dataclass
class BenchmarkRun:
    name: str
    device: str
    device_name: str
    config: dict
    seconds: float


def save_results(name: str, runs: list[BenchmarkRun]) -> str:
    """Write a benchmark's runs to results/<name>.json and return the path."""
    os.makedirs(RESULTS_DIR, exist_ok=True)
    path = os.path.join(RESULTS_DIR, f"{name}.json")
    payload = {
        "benchmark": name,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "torch_version": torch.__version__,
        "cuda_available": torch.cuda.is_available(),
        "runs": [asdict(r) for r in runs],
    }
    with open(path, "w") as f:
        json.dump(payload, f, indent=2)
    return path


def print_header(title: str) -> None:
    print("=" * 60)
    print(title)
    print("=" * 60)
    print(f"PyTorch {torch.__version__} | CUDA available: {torch.cuda.is_available()}")
    for d in available_devices():
        print(f"  - {d}: {device_label(d)}")
    print("-" * 60)
