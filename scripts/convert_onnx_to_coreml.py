#!/usr/bin/env python3
"""Convert an ONNX portrait-cartoonization model to a Core ML mlpackage.

Usage: convert_onnx_to_coreml.py <input.onnx> <output.mlpackage>

Modern coremltools no longer ships an ONNX frontend, so this script tries the
available paths in order and fails with actionable guidance instead of
producing a silently broken model.
"""
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    src, dst = sys.argv[1], sys.argv[2]

    import coremltools as ct  # noqa: PLC0415

    # Path 1: legacy ONNX converter (coremltools < 7 only).
    if hasattr(ct.converters, "onnx"):
        model = ct.converters.onnx.convert(model=src)
        model.save(dst)
        print(f"Converted via legacy ONNX frontend → {dst}")
        return 0

    # Path 2: onnx2torch bridge, if installed.
    try:
        import torch  # noqa: PLC0415
        from onnx2torch import convert as onnx2torch_convert  # noqa: PLC0415
        import onnx  # noqa: PLC0415

        onnx_model = onnx.load(src)
        torch_model = onnx2torch_convert(onnx_model).eval()

        # Assume a single NCHW float input; read its static shape.
        inp = onnx_model.graph.input[0]
        dims = [d.dim_value for d in inp.type.tensor_type.shape.dim]
        if len(dims) != 4 or any(d <= 0 for d in dims):
            print(f"Cannot infer a static input shape from ONNX input dims={dims}")
            return 1
        example = torch.rand(*dims)
        traced = torch.jit.trace(torch_model, example)
        mlmodel = ct.convert(
            traced,
            inputs=[ct.ImageType(name="image", shape=dims, scale=1 / 255.0)],
            minimum_deployment_target=ct.target.iOS17,
        )
        mlmodel.save(dst)
        print(f"Converted via onnx2torch bridge → {dst}")
        return 0
    except ImportError:
        pass

    print(
        "ERROR: No usable ONNX conversion path available.\n"
        "Options:\n"
        "  1. pip install onnx2torch torch and re-run, or\n"
        "  2. convert the model to .mlmodel/.mlpackage manually (see\n"
        "     https://apple.github.io/coremltools/) and re-run the workflow\n"
        "     with model_format=mlmodel or mlpackage."
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
