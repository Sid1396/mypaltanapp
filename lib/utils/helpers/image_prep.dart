import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Image shapes used before uploading. All work runs in an isolate and returns a JPEG file path.
enum ImageShape { square, banner, original }

class ImagePrep {
  ImagePrep._();

  static Future<String> toJpeg(String path, ImageShape shape) async {
    final bytes = await File(path).readAsBytes();
    final out = await compute(_process, (bytes, shape));
    final file = File('${path}_mp_${shape.name}.jpg');
    await file.writeAsBytes(out);
    return file.path;
  }
}

Uint8List _process((Uint8List, ImageShape) args) => switch (args.$2) {
      ImageShape.square => squareJpeg(args.$1),
      ImageShape.banner => bannerJpeg(args.$1),
      ImageShape.original => fitJpeg(args.$1),
    };

img.Image _decode(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Unsupported image');
  return img.bakeOrientation(decoded);
}

/// Centre-crops to a square, resizes to 600px and re-encodes as JPEG.
Uint8List squareJpeg(Uint8List bytes) {
  final o = _decode(bytes);
  final side = o.width < o.height ? o.width : o.height;
  final cropped = img.copyCrop(o, x: (o.width - side) ~/ 2, y: (o.height - side) ~/ 2, width: side, height: side);
  final resized = side > 600 ? img.copyResize(cropped, width: 600, height: 600) : cropped;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}

/// Centre-crops to 16:9 and resizes to at most 1600px wide.
Uint8List bannerJpeg(Uint8List bytes) {
  final o = _decode(bytes);
  var w = o.width, h = (o.width * 9 / 16).round();
  if (h > o.height) {
    h = o.height;
    w = (o.height * 16 / 9).round();
  }
  final cropped = img.copyCrop(o, x: (o.width - w) ~/ 2, y: (o.height - h) ~/ 2, width: w, height: h);
  final resized = w > 1600 ? img.copyResize(cropped, width: 1600) : cropped;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
}

/// Keeps the shape, limits the longest side to 1600px.
Uint8List fitJpeg(Uint8List bytes) {
  final o = _decode(bytes);
  final longest = o.width > o.height ? o.width : o.height;
  final resized = longest > 1600
      ? (o.width >= o.height ? img.copyResize(o, width: 1600) : img.copyResize(o, height: 1600))
      : o;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}
