import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/face_structure_service.dart';
import '../theme.dart';

class FaceVerifyLivePage extends StatefulWidget {
  final String email;
  const FaceVerifyLivePage({super.key, required this.email});

  @override
  State<FaceVerifyLivePage> createState() => _FaceVerifyLivePageState();
}

class _FaceVerifyLivePageState extends State<FaceVerifyLivePage> {
  CameraController? _controller;
  final _faceService = FaceStructureService();
  bool _verifying = false;
  bool _success = false;
  Timer? _timer;
  int _frameCount = 0;
  String _status = 'Mendeteksi wajah...';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
      _startVerificationLoop();
    } catch (e) {
      debugPrint('❌ Gagal inisialisasi kamera: $e');
      setState(() => _status = 'Kamera tidak dapat diakses');
    }
  }

  /// Loop verifikasi tiap 1.3 detik
  void _startVerificationLoop() {
    _timer = Timer.periodic(const Duration(milliseconds: 1300), (_) async {
      if (_verifying || _success || !mounted) return;
      _verifying = true;

      try {
        if (!(_controller?.value.isInitialized ?? false)) {
          _verifying = false;
          return;
        }

        final pic = await _controller!.takePicture();
        final bytes = await File(pic.path).readAsBytes();

        final currentStruct = await _faceService.extractStructure(bytes);
        if (currentStruct == null || currentStruct.isEmpty) {
          setState(() => _status = 'Wajah tidak terdeteksi');
          _verifying = false;
          return;
        }

        final saved = await DBService.getFaceStructureByEmail(widget.email);
        if (saved == null) {
          setState(() => _status = 'Data wajah tidak ditemukan');
          _verifying = false;
          return;
        }

        final sim = _faceService.compareStructures(currentStruct, saved);
        _frameCount++;
        debugPrint(
            '🔍 Frame $_frameCount → Similarity ${(sim * 100).toStringAsFixed(2)}%');

        if (sim >= 0.75) {
          if (!_success) {
            setState(() {
              _success = true;
              _status = 'Wajah cocok! Login berhasil...';
            });

            await Future.delayed(const Duration(seconds: 1));

            if (mounted) Navigator.pop(context, true);
          }
        } else {
          setState(() => _status = '⏳ Mendeteksi wajah...');
        }
      } catch (e) {
        debugPrint('❌ Error capture: $e');
        setState(() => _status = 'Terjadi kesalahan kamera');
      } finally {
        _verifying = false;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.dispose();
    }
    _faceService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Verifikasi Wajah'),
        backgroundColor: const Color.fromARGB(255, 225, 205, 245),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          CameraPreview(_controller!),
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _success
                        ? Icons.verified_user
                        : Icons.face_retouching_natural,
                    color: _success ? Colors.greenAccent : Colors.white,
                    size: 90,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Arahkan wajah ke kamera depan\nHindari cahaya gelap atau blur',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
