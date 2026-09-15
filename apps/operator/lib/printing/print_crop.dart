/// Center-crop rectangle into a frame with [aspectRatio] (width / height).
/// Pure Dart — no Flutter dependency — so ESC/POS tests can import it.
class CropRect {
  const CropRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
}

CropRect centerCropRect({
  required double sourceWidth,
  required double sourceHeight,
  required double aspectRatio,
}) {
  assert(aspectRatio > 0);
  assert(sourceWidth > 0 && sourceHeight > 0);

  final sourceAspect = sourceWidth / sourceHeight;
  if (sourceAspect > aspectRatio) {
    final cropWidth = sourceHeight * aspectRatio;
    final left = (sourceWidth - cropWidth) / 2;
    return CropRect(left, 0, cropWidth, sourceHeight);
  }
  final cropHeight = sourceWidth / aspectRatio;
  final top = (sourceHeight - cropHeight) / 2;
  return CropRect(0, top, sourceWidth, cropHeight);
}

/// Normalized crop (0–1) useful for painting without knowing pixel size yet.
CropRect centerCropNormalized({
  required double sourceAspect,
  required double targetAspect,
}) {
  assert(sourceAspect > 0 && targetAspect > 0);
  if (sourceAspect > targetAspect) {
    final w = targetAspect / sourceAspect;
    return CropRect((1 - w) / 2, 0, w, 1);
  }
  final h = sourceAspect / targetAspect;
  return CropRect(0, (1 - h) / 2, 1, h);
}
