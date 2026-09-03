"""Matrix-multiply benchmark: CPU vs GPU across a range of sizes.

Dense linear algebra is the bread and butter of deep learning (every fully-connected
layer is a matmul). This is where GPUs shine: thousands of cores doing the same
multiply-add in parallel. Small matrices barely benefit; large ones can be 10-50x faster.

Run:
    python matmul_benchmark.py
"""
from __future__ import annotations

import torch

from bench_utils import (
    BenchmarkRun,
    available_devices,
    device_label,
    print_header,
    save_results,
    time_op,
)

# Square matrix sizes (N x N). Grows the problem so you can see the crossover where
# the GPU starts to dominate.
SIZES = [256, 512, 1024, 2048, 4096]


def make_matmul(n: int, device: str):
    """Build a closure that multiplies two N x N matrices living on `device`.

    We allocate the inputs ONCE here (outside the timed loop) so we measure the matmul
    itself, not the cost of creating random data. `device=device` places the tensors in
    CPU RAM or GPU memory accordingly — that placement is the whole experiment.
    """
    a = torch.randn(n, n, device=device)
    b = torch.randn(n, n, device=device)

    def run():
        # `a @ b` is the matmul. The `.sum()` forces the result to be fully computed:
        # without using the output, a lazy/fused backend could legally skip work, which
        # would give misleadingly fast times. Summing is cheap next to an N^3 matmul.
        (a @ b).sum()

    return run


def main() -> None:
    print_header("Matrix Multiply Benchmark (CPU vs GPU)")

    runs: list[BenchmarkRun] = []
    for device in available_devices():
        name = device_label(device)
        for n in SIZES:
            op = make_matmul(n, device)
            secs = time_op(op, device)
            # Convert time into GFLOP/s so devices are comparable regardless of speed.
            # An N x N matmul does ~2*N^3 floating-point ops: each of the N*N output cells
            # is a dot product of length N (N multiplies + N adds = 2N ops). Divide the
            # total ops by seconds, then by 1e9 to get billions of FLOPs per second.
            gflops = (2 * n**3) / secs / 1e9
            print(f"[{device:4}] {n:>5} x {n:<5}  {secs * 1e3:9.3f} ms   {gflops:8.1f} GFLOP/s")
            runs.append(
                BenchmarkRun(
                    name="matmul",
                    device=device,
                    device_name=name,
                    config={"size": n, "gflops": round(gflops, 2)},
                    seconds=secs,
                )
            )

    path = save_results("matmul", runs)
    print("-" * 60)
    print(f"Saved results -> {path}")

    if "cuda" not in available_devices():
        print("\nNote: no CUDA GPU detected, so only CPU results were recorded.")
        print("Run this on the provisioned g4dn.xlarge instance to capture GPU numbers.")


if __name__ == "__main__":
    main()
