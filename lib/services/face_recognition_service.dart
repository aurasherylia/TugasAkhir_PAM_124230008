import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

class FaceRecognitionService {
  Interpreter? _interpreter;
  bool _isLoaded = false;
  late TensorType _inputType;
  late List<int> _outputShape;
  final ImagePicker _picker = ImagePicker();

  Future<void> loadModel() async {
    if (_isLoaded) return;

    const modelPath = 'assets/models/facenet.tflite';
    await rootBundle.load(modelPath);
    _interpreter = await Interpreter.fromAsset(modelPath);
    _inputType = _interpreter!.getInputTensor(0).type;
    _outputShape = _interpreter!.getOutputTensor(0).shape;
    _isLoaded = true;

    debugPrint('FaceNet model loaded successfully');
  }

  bool get isReady => _isLoaded && _interpreter != null;

  // CAPTURE FACE (HANYA DARI KAMERA)
  Future<Uint8List?> captureFaceImage(BuildContext context) async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 480,
      );
      if (image == null) return null;
      return await image.readAsBytes();
    } catch (e) {
      debugPrint('❌ Error capture face: $e');
      return null;
    }
  }

  // EXTRACT FACE EMBEDDING 
  Future<List<double>?> extractFaceEmbedding(Uint8List bytes) async {
    if (!_isLoaded) await loadModel();
    if (_interpreter == null) return null;

    try {
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('⚠️ Gagal decode gambar');
        return null;
      }

      image = img.bakeOrientation(image);

      final tempPath = await _saveTemp(img.encodeJpg(image));
      final inputImage = InputImage.fromFilePath(tempPath);

      final detector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableLandmarks: false,
          performanceMode: FaceDetectorMode.accurate,
          minFaceSize: 0.25,
        ),
      );

      final faces = await detector.processImage(inputImage);
      await detector.close();

      // Validasi wajah
      if (faces.isEmpty) {
        debugPrint('❌ Tidak ada wajah terdeteksi');
        return null;
      }
      if (faces.length > 1) {
        debugPrint('⚠️ Lebih dari satu wajah, tolak!');
        return null;
      }

      final face = faces.first;
      final rect = face.boundingBox;

      // Validasi ukuran wajah minimal (≥10% frame)
      final areaRatio =
          (rect.width * rect.height) / (image.width * image.height);
      if (areaRatio < 0.1) {
        debugPrint('⚠️ Wajah terlalu kecil di gambar ($areaRatio)');
        return null;
      }

      // Crop wajah
      final cropX = rect.left.toInt().clamp(0, image.width - 1);
      final cropY = rect.top.toInt().clamp(0, image.height - 1);
      final cropW = rect.width.toInt().clamp(1, image.width - cropX);
      final cropH = rect.height.toInt().clamp(1, image.height - cropY);
      final cropped = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      final resized = img.copyResize(cropped, width: 160, height: 160);
      final rgbBytes = resized.getBytes(order: img.ChannelOrder.rgb);
      final isUint8 = _inputType == TensorType.uint8;

      final input = List.generate(
        1,
        (_) => List.generate(
          160,
          (y) => List.generate(
            160,
            (x) {
              final idx = (y * 160 + x) * 3;
              final r = rgbBytes[idx];
              final g = rgbBytes[idx + 1];
              final b = rgbBytes[idx + 2];
              return isUint8
                  ? [r, g, b]
                  : [(r - 128) / 128.0, (g - 128) / 128.0, (b - 128) / 128.0];
            },
          ),
        ),
      );

      final embeddingDim = _outputShape.last;
      final output = List.filled(embeddingDim, 0.0).reshape([1, embeddingDim]);
      _interpreter!.run(input, output);

      final embedding =
          List<double>.from(output[0].map((e) => (e as num).toDouble()));
      final norm = sqrt(embedding.fold(0.0, (s, e) => s + e * e));
      final normalized =
          embedding.map((e) => e / (norm == 0 ? 1 : norm)).toList();

      debugPrint('🧠 Embedding berhasil diekstrak (${embeddingDim}D)');
      return normalized;
    } catch (e, st) {
      debugPrint('❌ Error extractFaceEmbedding: $e\n$st');
      return null;
    }
  }

  // COMPARE FACES
  bool isSameFace(List<double> a, List<double> b, {double threshold = 0.72}) {
    if (a.length != b.length) return false;
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      sum += pow(a[i] - b[i], 2);
    }
    final distance = sqrt(sum);
    debugPrint('📏 Distance wajah: ${distance.toStringAsFixed(4)}');
    return distance < threshold;
  }

  Future<String> _saveTemp(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
