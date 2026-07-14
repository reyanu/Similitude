#!/usr/bin/env python3
"""Convert an ONNX portrait-cartoonization model to a Core ML mlpackage.

Usage: convert_onnx_to_coreml.py <input.onnx> <output.mlpackage> [--generic]

Built for photo2cartoon (minivision-ai) by default: a UGATIT-style generator
with a 1x3x256x256 input normalized to [-1, 1] and a tanh output in [-1, 1]
(possibly alongside auxiliary CAM outputs, which are dropped). The conversion
wraps the network so the Core ML model exposes a plain image-in / image-out
interface:

  input:  RGB image at the model's native size (pixels 0-255, Core ML applies
          scale 2/255 and bias -1 to reach [-1, 1])
  output: RGB image (the wrapper maps [-1, 1] back to 0-255)

Pass --generic for a model that already works on [0, 1] inputs and outputs.
"""
import sys


def load_torch_model(src: str):
    import onnx
    from onnx2torch import convert

    onnx_model = onnx.load(src)
    graph_input = onnx_model.graph.input[0]
    shape = graph_input.type.tensor_type.shape
    dims = [d.dim_value for d in shape.dim]
    if len(dims) != 4:
        raise SystemExit(f"Expected a 4-D NCHW input, got dims={dims}")
    # Batch dim is often 0/unknown in exports; force 1.
    dims = [1, dims[1], dims[2] if dims[2] > 0 else 256, dims[3] if dims[3] > 0 else 256]

    # Pin static dims in the graph, then run shape inference — onnx2torch
    # needs per-node shapes (e.g. AveragePool spatial rank) to pick
    # converters, and many exports ship without value_info.
    for dim, value in zip(shape.dim, dims):
        dim.ClearField("dim_param")
        dim.dim_value = value
    onnx_model = onnx.shape_inference.infer_shapes(onnx_model)

    return convert(onnx_model).eval(), dims


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    if len(args) != 2:
        print(__doc__)
        return 2
    src, dst = args
    generic = "--generic" in flags

    import torch
    import coremltools as ct

    torch_model, dims = load_torch_model(src)
    print(f"Loaded ONNX model via onnx2torch; input shape {dims}")

    class CartoonWrapper(torch.nn.Module):
        """Drops auxiliary outputs and denormalizes to 0-255 RGB."""

        def __init__(self, inner: torch.nn.Module, denormalize: bool):
            super().__init__()
            self.inner = inner
            self.denormalize = denormalize

        def forward(self, x):
            out = self.inner(x)
            if isinstance(out, (tuple, list)):
                out = out[0]  # UGATIT returns (image, cam_logit, heatmap)
            if self.denormalize:
                out = (out + 1.0) * 127.5  # [-1,1] → [0,255]
            else:
                out = out * 255.0  # [0,1] → [0,255]
            return torch.clamp(out, 0.0, 255.0)

    wrapper = CartoonWrapper(torch_model, denormalize=not generic).eval()
    example = torch.rand(*dims) * 2 - 1 if not generic else torch.rand(*dims)
    traced = torch.jit.trace(wrapper, example)

    if generic:
        scale, bias = 1 / 255.0, None
    else:
        scale, bias = 2 / 255.0, [-1.0, -1.0, -1.0]

    mlmodel = ct.convert(
        traced,
        inputs=[ct.ImageType(
            name="image",
            shape=dims,
            scale=scale,
            bias=bias,
            color_layout=ct.colorlayout.RGB,
        )],
        outputs=[ct.ImageType(name="cartoon", color_layout=ct.colorlayout.RGB)],
        minimum_deployment_target=ct.target.iOS17,
        compute_units=ct.ComputeUnit.ALL,
    )
    mlmodel.short_description = "On-device portrait cartoonization (photo2cartoon)"
    mlmodel.save(dst)
    print(f"Saved Core ML package → {dst}")

    # Smoke-test: run one prediction through the converted model.
    import numpy as np
    from PIL import Image

    probe = Image.fromarray(
        (np.random.rand(dims[2], dims[3], 3) * 255).astype("uint8"), "RGB"
    )
    result = mlmodel.predict({"image": probe})
    out = result["cartoon"]
    print(f"Smoke inference OK; output type {type(out).__name__}, size {getattr(out, 'size', '?')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
