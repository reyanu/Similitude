#!/usr/bin/env python3
"""Convert photo2cartoon PyTorch weights to a Core ML mlpackage.

Usage: convert_photo2cartoon_pt.py <photo2cartoon_weights.pt> <output.mlpackage>
       [--repo photo2cartoon_repo]

Instantiates the UGATIT-style ResnetGenerator from the MIT-licensed
minivision-ai/photo2cartoon repository (must be cloned at --repo), loads the
genA2B weights, and converts via torch.jit.trace — no ONNX tooling involved.

The exported Core ML model is image-in / image-out:
  input  "image":   RGB, 256x256, pixels 0-255 (scale 2/255, bias -1 → [-1,1])
  output "cartoon": RGB, 256x256, pixels 0-255
"""
import argparse


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("weights")
    parser.add_argument("output")
    parser.add_argument("--repo", default="photo2cartoon_repo")
    args = parser.parse_args()

    import torch
    import coremltools as ct

    # Load models/networks.py directly by path: importing the repo's
    # `models` package pulls the trainer and its heavy preprocessing deps
    # (cv2, face-alignment, tensorflow) that conversion doesn't need.
    import importlib.util
    import os

    networks_path = os.path.join(args.repo, "models", "networks.py")
    spec = importlib.util.spec_from_file_location("p2c_networks", networks_path)
    networks = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(networks)
    ResnetGenerator = networks.ResnetGenerator

    net = ResnetGenerator(ngf=32, img_size=256, light=True)
    params = torch.load(args.weights, map_location="cpu", weights_only=True)
    net.load_state_dict(params["genA2B"])
    net.eval()
    print("Loaded genA2B weights into ResnetGenerator(ngf=32, img_size=256, light=True)")

    class CartoonWrapper(torch.nn.Module):
        """Keeps only the generated image and denormalizes to 0-255."""

        def __init__(self, inner: torch.nn.Module):
            super().__init__()
            self.inner = inner

        def forward(self, x):
            out = self.inner(x)[0]  # (image, cam_logit, heatmap)
            return torch.clamp((out + 1.0) * 127.5, 0.0, 255.0)

    wrapper = CartoonWrapper(net).eval()
    example = torch.rand(1, 3, 256, 256) * 2 - 1
    with torch.no_grad():
        traced = torch.jit.trace(wrapper, example)
    print("Traced generator")

    mlmodel = ct.convert(
        traced,
        inputs=[ct.ImageType(
            name="image",
            shape=(1, 3, 256, 256),
            scale=2 / 255.0,
            bias=[-1.0, -1.0, -1.0],
            color_layout=ct.colorlayout.RGB,
        )],
        outputs=[ct.ImageType(name="cartoon", color_layout=ct.colorlayout.RGB)],
        minimum_deployment_target=ct.target.iOS17,
        compute_units=ct.ComputeUnit.ALL,
    )
    mlmodel.short_description = "On-device portrait cartoonization (photo2cartoon, MIT)"
    mlmodel.save(args.output)
    print(f"Saved Core ML package → {args.output}")

    # Smoke-test one prediction before anything gets published.
    import numpy as np
    from PIL import Image

    probe = Image.fromarray(
        (np.random.rand(256, 256, 3) * 255).astype("uint8"), "RGB"
    )
    result = mlmodel.predict({"image": probe})
    out = result["cartoon"]
    print(f"Smoke inference OK; output type {type(out).__name__}, size {getattr(out, 'size', '?')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
