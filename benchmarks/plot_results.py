"""Render charts from the benchmark JSON in ../results/.

Produces website-ready PNGs:
  - results/matmul.png        CPU vs GPU time across matrix sizes (log scale)
  - results/cnn_training.png  CPU vs GPU throughput (images/sec)
  - results/speedup.png       GPU speedup factor summary

Run after the benchmarks:
    python plot_results.py
"""
from __future__ import annotations

import json
import os

import matplotlib

matplotlib.use("Agg")  # headless: works over SSH with no display
import matplotlib.pyplot as plt

RESULTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "results")


def load(name: str) -> dict | None:
    path = os.path.join(RESULTS_DIR, f"{name}.json")
    if not os.path.exists(path):
        print(f"skip: {path} not found (run the benchmark first)")
        return None
    with open(path) as f:
        return json.load(f)


def _runs_by_device(data: dict) -> dict[str, list[dict]]:
    by_device: dict[str, list[dict]] = {}
    for run in data["runs"]:
        by_device.setdefault(run["device"], []).append(run)
    return by_device


def plot_matmul(data: dict) -> None:
    by_device = _runs_by_device(data)

    plt.figure(figsize=(8, 5))
    for device, runs in by_device.items():
        runs = sorted(runs, key=lambda r: r["config"]["size"])
        sizes = [r["config"]["size"] for r in runs]
        ms = [r["seconds"] * 1e3 for r in runs]
        plt.plot(sizes, ms, marker="o", label=f"{device} ({runs[0]['device_name']})")

    plt.xlabel("Matrix size (N x N)")
    plt.ylabel("Time per matmul (ms)")
    plt.title("Matrix Multiply: CPU vs GPU")
    plt.yscale("log")
    plt.grid(True, which="both", linestyle="--", alpha=0.4)
    plt.legend()
    plt.tight_layout()
    out = os.path.join(RESULTS_DIR, "matmul.png")
    plt.savefig(out, dpi=150)
    plt.close()
    print(f"wrote {out}")


def plot_cnn(data: dict) -> None:
    by_device = _runs_by_device(data)

    devices = list(by_device.keys())
    throughput = [by_device[d][0]["config"]["images_per_sec"] for d in devices]
    labels = [f"{d}\n{by_device[d][0]['device_name']}" for d in devices]

    plt.figure(figsize=(6, 5))
    bars = plt.bar(labels, throughput, color=["#888888", "#76b900"][: len(devices)])
    plt.ylabel("Throughput (images / sec)")
    plt.title("CNN Training: CPU vs GPU")
    for bar, val in zip(bars, throughput):
        plt.text(bar.get_x() + bar.get_width() / 2, val, f"{val:.0f}",
                 ha="center", va="bottom")
    plt.grid(True, axis="y", linestyle="--", alpha=0.4)
    plt.tight_layout()
    out = os.path.join(RESULTS_DIR, "cnn_training.png")
    plt.savefig(out, dpi=150)
    plt.close()
    print(f"wrote {out}")


def plot_speedup(matmul: dict | None, cnn: dict | None) -> None:
    """Summarize GPU speedup vs CPU. Only meaningful when both devices were measured."""
    labels: list[str] = []
    speedups: list[float] = []

    if matmul:
        by_device = _runs_by_device(matmul)
        if "cpu" in by_device and "cuda" in by_device:
            cpu = {r["config"]["size"]: r["seconds"] for r in by_device["cpu"]}
            gpu = {r["config"]["size"]: r["seconds"] for r in by_device["cuda"]}
            largest = max(set(cpu) & set(gpu))
            labels.append(f"matmul\n{largest}x{largest}")
            speedups.append(cpu[largest] / gpu[largest])

    if cnn:
        by_device = _runs_by_device(cnn)
        if "cpu" in by_device and "cuda" in by_device:
            cpu_s = by_device["cpu"][0]["seconds"]
            gpu_s = by_device["cuda"][0]["seconds"]
            labels.append("CNN\ntraining")
            speedups.append(cpu_s / gpu_s)

    if not speedups:
        print("skip speedup chart: need both CPU and GPU results (run on the GPU instance)")
        return

    plt.figure(figsize=(6, 5))
    bars = plt.bar(labels, speedups, color="#76b900")
    plt.ylabel("GPU speedup (x faster than CPU)")
    plt.title("GPU Speedup Summary")
    for bar, val in zip(bars, speedups):
        plt.text(bar.get_x() + bar.get_width() / 2, val, f"{val:.1f}x",
                 ha="center", va="bottom")
    plt.grid(True, axis="y", linestyle="--", alpha=0.4)
    plt.tight_layout()
    out = os.path.join(RESULTS_DIR, "speedup.png")
    plt.savefig(out, dpi=150)
    plt.close()
    print(f"wrote {out}")


def main() -> None:
    matmul = load("matmul")
    cnn = load("cnn_training")

    if matmul:
        plot_matmul(matmul)
    if cnn:
        plot_cnn(cnn)
    plot_speedup(matmul, cnn)


if __name__ == "__main__":
    main()
