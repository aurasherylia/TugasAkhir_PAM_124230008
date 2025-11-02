import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Face recognition berbasis struktur wajah + liveness (tanpa embeddings & tanpa landmarks API).
/// Seluruh perhitungan diambil dari CONTOURS agar kompatibel lintas versi MLKit.
class FaceStructureService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: true,  // <-- WAJIB TRUE
      enableLandmarks: false, // <-- kita tidak pakai landmarks sama sekali
    ),
  );

  // Batas-batas aturan
  static const double minFaceAreaRatio = 0.10; // wajah minimal 10% frame
  static const double minStructureSimilarity = 0.86; // ambang kemiripan struktur
  static const double minBlinkDelta = 0.18; // kedipan mata (EAR turun)
  static const double minYawDeltaDeg = 12;  // gerakan kepala (derajat)

  /// Ekstrak fitur struktur wajah (rasio skala-invariant + EAR + yaw)
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

    // Validasi ukuran wajah relatif terhadap gambar
    final rect = face.boundingBox;
    final areaRatio = (rect.width * rect.height) / (im.width * im.height);
    if (areaRatio < minFaceAreaRatio) {
      debugPrint('⚠️ Wajah terlalu kecil ($areaRatio)');
      return null;
    }

    final feats = _computeFeaturesFromContours(face);
    if (feats.isEmpty) {
      debugPrint('⚠️ Fitur kosong (contour kurang lengkap)');
      return null;
    }
    return feats;
  }

  /// Bandingkan dua struktur (0..1), makin tinggi makin mirip
  double compareStructures(Map<String, double> a, Map<String, double> b) {
    const keys = [
      'eye_distance_norm',
      'nose_to_chin_norm',
      'face_height_norm',
      'eye_aspect_ratio',
      'yaw_deg',
    ];
    double sum = 0;
    int count = 0;

    for (final k in keys) {
      if (!a.containsKey(k) || !b.containsKey(k)) continue;
      final va = a[k]!;
      final vb = b[k]!;
      // relative error → similarity
      final rel = ((va - vb).abs()) / (((va + vb) / 2).abs() + 1e-6);
      sum += max(0.0, 1.0 - rel);
      count++;
    }
    return count == 0 ? 0.0 : sum / count;
  }

  /// Liveness: deteksi kedipan atau putar kepala
  bool evaluateLiveness({
    required Map<String, double> baseline,
    required Map<String, double> action,
  }) {
    final earOpen = baseline['eye_aspect_ratio'] ?? 0.0;
    final earNow  = action['eye_aspect_ratio'] ?? earOpen;
    final blink = (earOpen - earNow) >= minBlinkDelta;

    final yaw0 = baseline['yaw_deg'] ?? 0.0;
    final yaw1 = action['yaw_deg'] ?? yaw0;
    final headTurn = (yaw1 - yaw0).abs() >= minYawDeltaDeg;

    return blink || headTurn;
  }

  /// ====== PRIVATE: fitur dari contours (tanpa face.landmarks) ======

  Map<String, double> _computeFeaturesFromContours(Face face) {
    // Ambil pusat (centroid) sebuah contour → Offset
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

    // Jarak antar dua titik
    double _dist(Offset? a, Offset? b) {
      if (a == null || b == null) return 0.0;
      final dx = a.dx - b.dx;
      final dy = a.dy - b.dy;
      return sqrt(dx * dx + dy * dy);
    }

    // Titik penting dari contours:
    final leftEyeCenter  = _center(FaceContourType.leftEye);
    final rightEyeCenter = _center(FaceContourType.rightEye);

    // Untuk hidung, coba bridge (atas), fallback ke noseBottom (bawah)
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

    if (leftEyeCenter == null || rightEyeCenter == null || nose == null) {
      debugPrint('⚠️ Contour penting tidak lengkap (mata/hidung)');
      return {};
    }

    // Dimensi wajah dari bounding box
    final faceWidth  = face.boundingBox.width;
    final faceHeight = face.boundingBox.height;

    // Rasio jarak mata terhadap lebar wajah
    final eyeDist = _dist(leftEyeCenter, rightEyeCenter);

    // Estimasi dagu = bagian bawah bounding box
    final chinY = face.boundingBox.bottom; // pakai BB bawah
    final noseToChin = chinY - nose.dy;

    // EAR dari contours (kedipan)
    final ear = _calculateEARFromContours(face);

    // Yaw (derajat) dari MLKit (jika null → 0)
    final yaw = face.headEulerAngleY ?? 0.0;

    // Safety divide
    final eyeDistanceNorm = faceWidth == 0 ? 0.0 : eyeDist / faceWidth;
    final noseToChinNorm  = faceHeight == 0 ? 0.0 : noseToChin / faceHeight;
    final faceHeightNorm  = faceWidth == 0 ? 0.0 : faceHeight / faceWidth;

    return {
      'eye_distance_norm': eyeDistanceNorm,
      'nose_to_chin_norm': noseToChinNorm,
      'face_height_norm' : faceHeightNorm,
      'eye_aspect_ratio' : ear,
      'yaw_deg'          : yaw,
    };
  }

  /// EAR dari contours mata kiri & kanan (butuh minimal 6 titik per mata)
  double _calculateEARFromContours(Face face) {
    final left  = face.contours[FaceContourType.leftEye]?.points;
    final right = face.contours[FaceContourType.rightEye]?.points;
    if (left == null || right == null || left.length < 6 || right.length < 6) {
      return 0.0;
    }

    double d(p, q) => sqrt(pow(p.x - q.x, 2) + pow(p.y - q.y, 2));

    // Indeks referensi sederhana (0..5) — MLKit bisa berbeda urutan,
    // tapi pola rasio tetap stabil (atas-bawah vs kiri-kanan).
    final leftEar  = d(left[1], left[5]) / (d(left[0], left[3]) + 1e-6);
    final rightEar = d(right[1], right[5]) / (d(right[0], right[3]) + 1e-6);

    return (leftEar + rightEar) / 2.0;
    // Catatan: jika ingin lebih stabil, bisa gunakan median beberapa pasangan titik.
  }

  /// Simpan gambar sementara agar bisa diproses MLKit
  Future<String> _saveTemp(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  void close() => _detector.close();
}
