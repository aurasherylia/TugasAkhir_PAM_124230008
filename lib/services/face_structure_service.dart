import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// ✅ Face recognition berbasis struktur + tekstur + liveness check.
/// Kompatibel penuh dengan `image: ^4.x.x`.
class FaceStructureService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: true,
      enableLandmarks: false,
    ),
  );

  // Ambang batas dan sensitivitas
  static const double minFaceAreaRatio = 0.10;
  static const double minStructureSimilarity = 0.85; // ✅ ubah ke 85%
  static const double minBlinkDelta = 0.18;
  static const double minYawDeltaDeg = 12;

  /// Ekstrak fitur wajah (struktur + tekstur)
  Future<Map<String, double>?> extractStructure(Uint8List bytes) async {
    img.Image? im = img.decodeImage(bytes);
    if (im == null) return null;
    im = img.bakeOrientation(im);

    final path = await _saveTemp(img.encodeJpg(im));
    final inputImage = InputImage.fromFilePath(path);

    final faces = await _detector.processImage(inputImage);
    if (faces.isEmpty) {
      debugPrint('❌ Tidak ada wajah');
      return null;
    }
    if (faces.length > 1) {
      debugPrint('❌ Lebih dari satu wajah');
      return null;
    }

    final face = faces.first;
    final rect = face.boundingBox;

    final areaRatio = (rect.width * rect.height) / (im.width * im.height);
    if (areaRatio < minFaceAreaRatio) {
      debugPrint('⚠️ Wajah terlalu kecil ($areaRatio)');
      return null;
    }

    final feats = _computeFeaturesFromContours(face);
    if (feats.isEmpty) {
      debugPrint('⚠️ Contour wajah tidak lengkap');
      return null;
    }

    // Tambahkan fitur tekstur wajah
    feats['face_area_norm'] = areaRatio;
    feats['brightness'] = _calculateMeanBrightness(im, rect);
    feats['color_var'] = _calculateColorVariance(im, rect);

    return feats;
  }

  /// Bandingkan dua struktur wajah (0..1)
  double compareStructures(Map<String, double> a, Map<String, double> b) {
    const keys = [
      'eye_distance_norm',
      'nose_to_chin_norm',
      'face_height_norm',
      'eye_aspect_ratio',
      'yaw_deg',
      'face_area_norm',
      'brightness',
      'color_var',
    ];

    double sum = 0;
    int count = 0;

    for (final k in keys) {
      if (!a.containsKey(k) || !b.containsKey(k)) continue;
      final va = a[k]!;
      final vb = b[k]!;
      final rel = ((va - vb).abs()) / (((va + vb) / 2).abs() + 1e-6);
      sum += max(0.0, 1.0 - rel);
      count++;
    }

    return count == 0 ? 0.0 : (sum / count).clamp(0.0, 1.0);
  }

  /// Deteksi kedipan atau gerakan kepala (liveness)
  bool evaluateLiveness({
    required Map<String, double> baseline,
    required Map<String, double> action,
  }) {
    final earOpen = baseline['eye_aspect_ratio'] ?? 0.0;
    final earNow = action['eye_aspect_ratio'] ?? earOpen;
    final blink = (earOpen - earNow) >= minBlinkDelta;

    final yaw0 = baseline['yaw_deg'] ?? 0.0;
    final yaw1 = action['yaw_deg'] ?? yaw0;
    final headTurn = (yaw1 - yaw0).abs() >= minYawDeltaDeg;

    return blink || headTurn;
  }

  // ===============================================================
  // PRIVATE: PERHITUNGAN STRUKTUR & TEKSTUR
  // ===============================================================

  Map<String, double> _computeFeaturesFromContours(Face face) {
    Offset? _center(FaceContourType type) {
      final pts = face.contours[type]?.points;
      if (pts == null || pts.isEmpty) return null;
      double sx = 0, sy = 0;
      for (final p in pts) {
        sx += p.x;
        sy += p.y;
      }
      return Offset(sx / pts.length, sy / pts.length);
    }

    double _dist(Offset? a, Offset? b) {
      if (a == null || b == null) return 0.0;
      final dx = a.dx - b.dx;
      final dy = a.dy - b.dy;
      return sqrt(dx * dx + dy * dy);
    }

    final leftEye = _center(FaceContourType.leftEye);
    final rightEye = _center(FaceContourType.rightEye);
    Offset? _noseCenter() {
      final bridge = face.contours[FaceContourType.noseBridge]?.points;
      if (bridge != null && bridge.isNotEmpty) {
        final last = bridge.last;
        return Offset(last.x.toDouble(), last.y.toDouble());
      }
      final bottom = face.contours[FaceContourType.noseBottom]?.points;
      if (bottom != null && bottom.isNotEmpty) {
        final c = bottom[bottom.length ~/ 2];
        return Offset(c.x.toDouble(), c.y.toDouble());
      }
      return null;
    }

    final nose = _noseCenter();
    if (leftEye == null || rightEye == null || nose == null) {
      return {};
    }

    final faceWidth = face.boundingBox.width;
    final faceHeight = face.boundingBox.height;
    final eyeDist = _dist(leftEye, rightEye);
    final chinY = face.boundingBox.bottom;
    final noseToChin = chinY - nose.dy;

    final ear = _calculateEARFromContours(face);
    final yaw = face.headEulerAngleY ?? 0.0;

    return {
      'eye_distance_norm': faceWidth == 0 ? 0.0 : eyeDist / faceWidth,
      'nose_to_chin_norm': faceHeight == 0 ? 0.0 : noseToChin / faceHeight,
      'face_height_norm': faceWidth == 0 ? 0.0 : faceHeight / faceWidth,
      'eye_aspect_ratio': ear,
      'yaw_deg': yaw,
    };
  }

  /// Hitung Eye Aspect Ratio (EAR)
  double _calculateEARFromContours(Face face) {
    final left = face.contours[FaceContourType.leftEye]?.points;
    final right = face.contours[FaceContourType.rightEye]?.points;
    if (left == null || right == null || left.length < 6 || right.length < 6) {
      return 0.0;
    }

    double d(p, q) => sqrt(pow(p.x - q.x, 2) + pow(p.y - q.y, 2));
    final leftEar = d(left[1], left[5]) / (d(left[0], left[3]) + 1e-6);
    final rightEar = d(right[1], right[5]) / (d(right[0], right[3]) + 1e-6);
    return (leftEar + rightEar) / 2.0;
  }

  /// Rata-rata brightness wajah
  double _calculateMeanBrightness(img.Image im, Rect box) {
    int startX = box.left.round().clamp(0, im.width - 1);
    int startY = box.top.round().clamp(0, im.height - 1);
    int endX = box.right.round().clamp(0, im.width);
    int endY = box.bottom.round().clamp(0, im.height);

    double sum = 0;
    int count = 0;

    for (int y = startY; y < endY; y += 3) {
      for (int x = startX; x < endX; x += 3) {
        final pixel = im.getPixel(x, y);
        final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
        sum += gray;
        count++;
      }
    }
    return count == 0 ? 0.0 : sum / count;
  }

  /// Variansi warna wajah
  double _calculateColorVariance(img.Image im, Rect box) {
    int startX = box.left.round().clamp(0, im.width - 1);
    int startY = box.top.round().clamp(0, im.height - 1);
    int endX = box.right.round().clamp(0, im.width);
    int endY = box.bottom.round().clamp(0, im.height);

    List<double> vals = [];

    for (int y = startY; y < endY; y += 5) {
      for (int x = startX; x < endX; x += 5) {
        final pixel = im.getPixel(x, y);
        final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
        vals.add(gray);
      }
    }

    if (vals.isEmpty) return 0.0;
    final mean = vals.reduce((a, b) => a + b) / vals.length;
    final varSum =
        vals.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / vals.length;
    return sqrt(varSum);
  }

  /// Simpan file sementara
  Future<String> _saveTemp(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  void close() => _detector.close();
}
