#!/usr/bin/env python3
"""
Turn your spaghetti detection model into a Core ML model the Bambu Bay app can load.

Run it on your computer (Mac, Windows or Linux), then send the .zip it makes to your
iPhone or iPad (AirDrop, Files, iCloud Drive) and open Watch > Import model in the app.

    python3 tools/convert_model.py path/to/your_model.pt

What it understands:
  * Ultralytics YOLO models (.pt from YOLOv5u, v8, 11 ...)      -> object detector (best)
  * Other PyTorch image models (.pt / .pth / TorchScript)        -> classifier or raw output
  * ONNX models (.onnx)                                          -> raw output (needs onnx2torch)
  * Core ML models you already have (.mlmodel / .mlpackage)      -> just zipped for the app

Install first (one time):
    pip install coremltools ultralytics          # for YOLO .pt files
    pip install coremltools torch torchvision    # for other PyTorch files
    pip install coremltools onnx onnx2torch torch  # for .onnx files

Options:
    --imgsz 640           input size the model was trained with (YOLO default 640, others 224)
    --labels "a,b,c"      class names in order (only needed if the file doesn't have them)
    --normalize imagenet  for classifiers trained with ImageNet mean/std normalisation
    --out folder          where to put the result (default: next to the input file)
    --name SpaghettiNet   name of the output file

Darknet files (.weights / .cfg, like the original Obico/The Spaghetti Detective model) are
not supported directly: convert them to ONNX or retrain with Ultralytics first.
"""

import argparse
import os
import shutil
import sys
import zipfile
from pathlib import Path


def fail(message: str) -> None:
    print(f"\nError: {message}", file=sys.stderr)
    sys.exit(1)


def need(module: str, pip_name: str):
    try:
        return __import__(module)
    except ImportError:
        fail(f"'{module}' isn't installed. Run:  pip install {pip_name}")


def names_metadata(labels):
    """The same {0: 'name'} text Ultralytics writes, which the app reads back."""
    return "{" + ", ".join(f"{i}: '{name}'" for i, name in enumerate(labels)) + "}"


def zip_model(model_path: Path, out_dir: Path) -> Path:
    """Zips a .mlpackage folder (or .mlmodel file) so it moves to a phone as one file."""
    out_dir.mkdir(parents=True, exist_ok=True)
    zip_path = out_dir / (model_path.name + ".zip")
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        if model_path.is_dir():
            for root, _dirs, files in os.walk(model_path):
                for f in sorted(files):
                    full = Path(root) / f
                    z.write(full, Path(model_path.name) / full.relative_to(model_path))
        else:
            z.write(model_path, model_path.name)
    return zip_path


# ---------------------------------------------------------------- Ultralytics YOLO

def is_ultralytics(path: Path) -> bool:
    try:
        import torch
    except ImportError:
        return True  # can't tell; let the YOLO path try and explain
    try:
        ckpt = torch.load(str(path), map_location="cpu", weights_only=False)
    except TypeError:  # older torch has no weights_only
        try:
            ckpt = torch.load(str(path), map_location="cpu")
        except ModuleNotFoundError as error:
            return "ultralytics" in str(error) or "models" in str(error)
        except Exception:
            return False
    except ModuleNotFoundError as error:
        # YOLO checkpoints need the ultralytics package (or the yolov5 repo) to open.
        return "ultralytics" in str(error) or "models" in str(error)
    except Exception:
        return False
    if isinstance(ckpt, dict) and ("model" in ckpt or "ema" in ckpt) and ("train_args" in ckpt or "date" in ckpt or "version" in ckpt):
        return True
    model = ckpt.get("model") if isinstance(ckpt, dict) else ckpt
    return type(model).__module__.startswith("ultralytics") or type(model).__module__.startswith("models.")


def convert_yolo(path: Path, args) -> Path:
    need("coremltools", "coremltools")
    ultralytics = need("ultralytics", "ultralytics")
    from ultralytics import YOLO

    print(f"Loading YOLO model {path.name} (ultralytics {ultralytics.__version__}) ...")
    try:
        model = YOLO(str(path))
    except Exception as error:
        fail(f"Ultralytics couldn't open this file ({error}). If it was trained with the original yolov5 repo, "
             "run its export instead:  python export.py --weights your.pt --include coreml --nms  "
             "then run this script on the .mlmodel it makes.")
    task = getattr(model, "task", "detect")
    names = getattr(model, "names", None) or {}
    print(f"Task: {task}. Classes: {names}")
    imgsz = args.imgsz or 640
    if task == "classify":
        exported = model.export(format="coreml", imgsz=imgsz)
    else:
        if task != "detect":
            print(f"Note: '{task}' models are exported as detectors; boxes may be missing.")
        # nms=True adds the confidence/coordinates outputs that Apple's Vision reads as boxes.
        exported = model.export(format="coreml", nms=True, imgsz=imgsz)
    result = Path(str(exported))
    if not result.exists():
        fail(f"Ultralytics said it exported {result}, but it isn't there.")
    final = (Path(args.out) if args.out else path.parent) / f"{args.name or path.stem}{result.suffix}"
    if final.resolve() != result.resolve():
        if final.exists():
            shutil.rmtree(final) if final.is_dir() else final.unlink()
        shutil.move(str(result), str(final))
    return final


# ---------------------------------------------------------------- Plain PyTorch / ONNX

def load_torch_model(path: Path):
    torch = need("torch", "torch")
    try:
        model = torch.jit.load(str(path), map_location="cpu")
        print("Loaded a TorchScript model.")
        return model
    except Exception:
        pass
    try:
        obj = torch.load(str(path), map_location="cpu", weights_only=False)
    except TypeError:
        obj = torch.load(str(path), map_location="cpu")
    if isinstance(obj, torch.nn.Module):
        print("Loaded a full PyTorch model.")
        return obj
    if isinstance(obj, dict):
        for key in ("model", "ema", "net", "module"):
            if isinstance(obj.get(key), torch.nn.Module):
                print(f"Loaded the model stored under '{key}'.")
                return obj[key]
        fail("This file only holds weights (a state_dict), not the model itself. "
             "Save it with torch.jit.save(torch.jit.script(model), 'model.pt') or torch.save(model, 'model.pt') "
             "from your training code, then run this again.")
    fail("Couldn't find a PyTorch model in this file.")


def load_onnx_as_torch(path: Path):
    need("onnx", "onnx")
    onnx2torch = need("onnx2torch", "onnx2torch")
    print("Converting ONNX to PyTorch with onnx2torch ...")
    return onnx2torch.convert(str(path))


def convert_torch(model, path: Path, args) -> Path:
    torch = need("torch", "torch")
    ct = need("coremltools", "coremltools")
    model = model.float().eval()
    imgsz = args.imgsz or 224
    example = torch.rand(1, 3, imgsz, imgsz)
    with torch.no_grad():
        out = model(example)
        traced = torch.jit.trace(model, example, strict=False)
    if isinstance(out, (list, tuple)):
        out = out[0]
    shape = tuple(out.shape)
    print(f"Model output shape: {shape}")

    labels = [s.strip() for s in args.labels.split(",") if s.strip()] if args.labels else []
    is_classifier = len(shape) == 2 and shape[0] == 1 and shape[1] <= 1000
    if args.normalize == "imagenet":
        # Core ML: (pixel * scale + bias) per channel; std is averaged since scale is one number.
        mean, std = (0.485, 0.456, 0.406), (0.229, 0.224, 0.225)
        s = 1 / (255.0 * (sum(std) / 3))
        scale, bias = s, [-m / sd for m, sd in zip(mean, std)]
    else:
        scale, bias = 1 / 255.0, [0.0, 0.0, 0.0]
    image = ct.ImageType(name="image", shape=example.shape, scale=scale, bias=bias,
                         color_layout=ct.colorlayout.RGB)

    kwargs = dict(inputs=[image], convert_to="mlprogram", minimum_deployment_target=ct.target.iOS16)
    if is_classifier:
        if not labels:
            labels = [f"class_{i}" for i in range(shape[1])]
            print("No --labels given, so classes are named class_0, class_1 ... "
                  "Pass --labels \"good,spaghetti\" so the app knows which class is a failure.")
        if len(labels) != shape[1]:
            fail(f"--labels has {len(labels)} names but the model has {shape[1]} classes.")
        print("Making a classifier. Tip: if the outputs aren't probabilities yet, the app still compares them, "
              "but adding softmax in your model gives cleaner scores.")
        kwargs["classifier_config"] = ct.ClassifierConfig(labels)
    else:
        print("Output isn't a class list, so it's kept as a raw output. The app reads YOLO-style outputs "
              "([1, 4+classes, boxes] or [1, boxes, 5+classes]).")

    mlmodel = ct.convert(traced, **kwargs)
    if labels:
        mlmodel.user_defined_metadata["names"] = names_metadata(labels)
    mlmodel.user_defined_metadata["imgsz"] = str(imgsz)
    mlmodel.short_description = "Print failure detector for Bambu Bay"
    final = (Path(args.out) if args.out else path.parent) / f"{args.name or path.stem}.mlpackage"
    if final.exists():
        shutil.rmtree(final)
    mlmodel.save(str(final))
    return final


# ---------------------------------------------------------------- main

def main() -> None:
    parser = argparse.ArgumentParser(description="Convert a spaghetti detection model for the Bambu Bay app.")
    parser.add_argument("model", help="your model file (.pt, .pth, .onnx, .mlmodel or .mlpackage)")
    parser.add_argument("--imgsz", type=int, default=0, help="input size the model was trained with")
    parser.add_argument("--labels", default="", help='class names in order, like "good,spaghetti"')
    parser.add_argument("--normalize", choices=["none", "imagenet"], default="none")
    parser.add_argument("--out", default="", help="output folder")
    parser.add_argument("--name", default="", help="output name (no extension)")
    args = parser.parse_args()

    path = Path(args.model).expanduser()
    if not path.exists():
        fail(f"{path} doesn't exist.")
    suffix = path.suffix.lower()
    out_dir = Path(args.out) if args.out else path.parent

    if suffix in (".mlmodel", ".mlpackage"):
        result = path
    elif suffix in (".weights", ".cfg"):
        fail("Darknet models aren't supported. Export to ONNX first, or retrain with Ultralytics YOLO.")
    elif suffix == ".onnx":
        result = convert_torch(load_onnx_as_torch(path), path, args)
    elif suffix in (".pt", ".pth", ".torchscript", ".ptl"):
        if is_ultralytics(path):
            result = convert_yolo(path, args)
        else:
            result = convert_torch(load_torch_model(path), path, args)
    else:
        fail(f"Don't know how to read '{suffix}' files. Use .pt, .pth, .onnx, .mlmodel or .mlpackage.")

    zipped = zip_model(result, out_dir)
    size_mb = zipped.stat().st_size / 1_000_000
    print("\nDone!")
    print(f"  Core ML model: {result}")
    print(f"  Send this to your phone: {zipped}  ({size_mb:.1f} MB)")
    print("  In Bambu Bay: Watch > Import model, then pick that .zip.")


if __name__ == "__main__":
    main()
