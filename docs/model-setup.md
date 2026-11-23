# Putting your spaghetti model on the phone

Bambu Bay runs your model on the iPhone or iPad itself with Apple's Core ML, so it works without a
computer once it's imported. Your model has to be turned into Core ML first. That's one command.

## 1. Install the tools (one time)

On your computer, with Python 3.9 or newer:

| Your model | Install |
|---|---|
| Ultralytics YOLO `.pt` (YOLOv5u, v8, 11) | `pip install coremltools ultralytics` |
| Other PyTorch `.pt` / `.pth` | `pip install coremltools torch torchvision` |
| `.onnx` | `pip install coremltools onnx onnx2torch torch` |

## 2. Convert

From the Bambu Bay project folder:

```
python3 tools/convert_model.py path/to/best.pt
```

Useful options:

- `--imgsz 640` the size the model was trained at (YOLO default 640, classifiers 224).
- `--labels "good,spaghetti"` class names in order, if the file doesn't store them.
- `--normalize imagenet` for classifiers trained with ImageNet mean/std.

It prints where it saved the result, for example `best.mlpackage.zip`.

Models trained with the original `yolov5` repo (not Ultralytics' newer package): run that repo's
`python export.py --weights best.pt --include coreml --nms`, then run this script on the
`.mlmodel` it makes so it gets zipped.

## 3. Send it to the phone

AirDrop the `.zip` to your iPhone or iPad (save it to Files), or put it in iCloud Drive.

## 4. Import

In the app: **Watch > Import model**, pick the `.zip`. The app compiles the model on the device
(a few seconds) and shows what kind it is and its class names.

## 5. Watch a printer

Switch on a printer in the Watch tab. While it's printing, the app checks a camera picture every
15 seconds (you can change this). A failure is called when, by default, 3 of the last 4 checks score
over 60%. Then:

- **Auto-pause off (default):** you get a notification and the app asks "Pause the print?".
- **Auto-pause on:** the app pauses the print and tells you.

**Failure words** decide which class names count as a failure (default: spaghetti, failure, fail,
defect, stringing, blob, detached, warp). Names like good, ok, normal or background never count.
A model with only one class counts every detection.

The app has to be open (it can be in the foreground on an iPad on a stand next to the printer;
turn on **Keep screen on**). iOS doesn't let apps watch a camera in the background.

## What kinds of models work

- **Object detectors** exported with NMS (Ultralytics `nms=True`): best, boxes are drawn on the picture.
- **Image classifiers:** the score is how sure the model is that the picture shows a failure.
- **Raw YOLO outputs** (`[1, 4+classes, boxes]` or `[1, boxes, 5+classes]`): decoded in the app.
