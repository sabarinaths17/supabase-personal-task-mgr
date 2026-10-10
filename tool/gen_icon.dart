// Run from project root: dart run tool/gen_icon.dart
// Generates a simple 512x512 app icon: indigo background + white checkmark.
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const size = 512;
  final bg = img.ColorRgb8(67, 56, 202); // #4338CA indigo
  final white = img.ColorRgb8(255, 255, 255);
  final image = img.Image(width: size, height: size);

  // Indigo fill
  img.fill(image, color: bg);

  // Rounded rect mask (inset 30px, radius 80)
  final mask = img.Image(width: size, height: size);
  img.fill(mask, color: img.ColorRgb8(0, 0, 0));
  img.fillRect(
    mask,
    x1: 30, y1: 30, x2: size - 30, y2: size - 30,
    color: img.ColorRgb8(255, 255, 255),
    radius: 80,
  );
  // Apply mask: clear corners
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (mask.getPixel(x, y).r < 128) {
        image.setPixel(x, y, img.ColorRgb8(67, 56, 202));
      }
    }
  }

  // Checkmark — two line segments with thick pen
  // Short stroke: (146, 270) → (220, 355)
  // Long stroke:  (220, 355) → (370, 155)
  const thickness = 36;
  img.drawLine(image, x1: 146, y1: 270, x2: 220, y2: 355, color: white, thickness: thickness, antialias: true);
  img.drawLine(image, x1: 220, y1: 355, x2: 370, y2: 155, color: white, thickness: thickness, antialias: true);

  final pngBytes = img.encodePng(image);
  final outPath = 'assets/icon/app_icon.png';
  File(outPath).writeAsBytesSync(pngBytes);
  // Same image as foreground for adaptive icon
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(pngBytes);
  print('Generated $outPath (${pngBytes.length} bytes)');
}
