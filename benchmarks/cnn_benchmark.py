"""CNN training benchmark: CPU vs GPU.

Trains a small convolutional network on synthetic image-shaped data for a fixed number
of steps and reports images/second. Convolutions map extremely well to GPU hardware, so
this is a realistic "how much faster is training" number without needing to download a
dataset (keeps the instance cheap and the run reproducible).

Run:
    python cnn_benchmark.py
"""
from __future__ import annotations

import torch
import torch.nn as nn

from bench_utils import (
    BenchmarkRun,
    available_devices,
    device_label,
    print_header,
    save_results,
    synchronize,
    time_op,
)

BATCH_SIZE = 64
IMAGE_SIZE = 32          # 3 x 32 x 32, CIFAR-like
NUM_CLASSES = 10
STEPS_PER_MEASURE = 5    # forward + backward + optimizer steps per timed iteration


class SmallCNN(nn.Module):
    """A compact CNN — enough conv/pool/linear layers to be representative."""

    def __init__(self, num_classes: int = NUM_CLASSES) -> None:
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(3, 32, kernel_size=3, padding=1),
            nn.ReLU(inplace=True),
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2),
            nn.Conv2d(64, 128, kernel_size=3, padding=1),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2),
        )
        self.classifier = nn.Sequential(
            nn.Flatten(),
            nn.Linear(128 * (IMAGE_SIZE // 4) * (IMAGE_SIZE // 4), 256),
            nn.ReLU(inplace=True),
            nn.Linear(256, num_classes),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.classifier(self.features(x))


def make_train_step(device: str):
    model = SmallCNN().to(device)
    optimizer = torch.optim.SGD(model.parameters(), lr=0.01, momentum=0.9)
    criterion = nn.CrossEntropyLoss()

    # Synthetic batch with the exact shape of real image data: (batch, channels, H, W).
    # Using random tensors means we measure raw training *speed* without downloading a
    # dataset. Accuracy is meaningless here (labels are random) and that's fine — the
    # per-step compute cost is identical whether the data is real or random.
    inputs = torch.randn(BATCH_SIZE, 3, IMAGE_SIZE, IMAGE_SIZE, device=device)
    targets = torch.randint(0, NUM_CLASSES, (BATCH_SIZE,), device=device)

    model.train()

    def run():
        # One training step is the standard four-part cycle repeated over the batch:
        for _ in range(STEPS_PER_MEASURE):
            optimizer.zero_grad(set_to_none=True)  # clear gradients from the previous step
            outputs = model(inputs)                # forward pass: predictions
            loss = criterion(outputs, targets)     # how wrong the predictions are
            loss.backward()                        # backward pass: gradients (the heavy part)
            optimizer.step()                       # update the weights
        # The forward+backward passes are dominated by convolutions, which are exactly the
        # kind of dense, parallel work a GPU accelerates most.

    return run


def main() -> None:
    print_header("CNN Training Benchmark (CPU vs GPU)")

    runs: list[BenchmarkRun] = []
    for device in available_devices():
        name = device_label(device)
        step = make_train_step(device)
        # Fewer iters here — a CPU pass over the whole thing is slow.
        secs = time_op(step, device, warmup=2, iters=5)
        synchronize(device)

        per_step = secs / STEPS_PER_MEASURE
        images_per_sec = BATCH_SIZE / per_step
        print(
            f"[{device:4}] {name}\n"
            f"        {per_step * 1e3:8.2f} ms/step   {images_per_sec:8.1f} images/sec"
        )
        runs.append(
            BenchmarkRun(
                name="cnn_training",
                device=device,
                device_name=name,
                config={
                    "batch_size": BATCH_SIZE,
                    "image_size": IMAGE_SIZE,
                    "images_per_sec": round(images_per_sec, 1),
                },
                seconds=per_step,
            )
        )

    path = save_results("cnn_training", runs)
    print("-" * 60)
    print(f"Saved results -> {path}")

    if "cuda" not in available_devices():
        print("\nNote: no CUDA GPU detected, so only CPU results were recorded.")
        print("Run this on the provisioned g4dn.xlarge instance to capture GPU numbers.")


if __name__ == "__main__":
    main()
