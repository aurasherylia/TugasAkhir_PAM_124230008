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
  double _similarity = 0.0;
  String _status = 'Mendeteksi wajah...';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  // Inisialisasi kamera 
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

  void _startVerificationLoop() {
    _timer = Timer.periodic(const Duration(milliseconds: 2000), (_) async {
      if (_verifying || _success || !mounted) return;
      _verifying = true;

      try {
        if (!(_controller?.value.isInitialized ?? false)) {
          _verifying = false;
          return;
        }

        // Ambil gambar dari kamera
        final pic = await _controller!.takePicture();
        await Future.delayed(const Duration(milliseconds: 600)); 

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
        _similarity = sim * 100;
        debugPrint('🔍 Frame $_frameCount → Similarity ${_similarity.toStringAsFixed(2)}%');


        if (sim >= FaceStructureService.minStructureSimilarity && !_success) {
          _timer?.cancel();
          _success = true;
          setState(() {
            _status = 'Wajah cocok! Login berhasil...';
            _similarity = sim * 100;
          });

          await Future.delayed(const Duration(milliseconds: 1300));

          if (mounted) {
            Navigator.pop(context, true);
          }
        } else if (!_success) {
          setState(() {
            if (_similarity >= 70) {
              _status = 'Wajah hampir cocok (${_similarity.toStringAsFixed(1)}%)';
            } else {
              _status = 'Mendeteksi wajah...';
            }
          });
        }
      } catch (e) {
        if (e.toString().contains("Cannot Record")) {
          debugPrint('Kamera belum siap, skip frame.');
          await Future.delayed(const Duration(milliseconds: 600));
          _verifying = false;
          return;
        }
        debugPrint('Error capture: $e');
        if (mounted) {
          setState(() => _status = 'Terjadi kesalahan kamera');
        }
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
        body: Center(
          child: CircularProgressIndicator(color: kPrimary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Verifikasi Wajah'),
        backgroundColor: const Color.fromARGB(255, 225, 205, 245),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          CameraPreview(_controller!),

          Container(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _success ? Icons.verified_user : Icons.face_retouching_natural,
                    color: _success ? Colors.greenAccent : Colors.white,
                    size: 100,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),

                  // Progress bar kemiripan
                  Container(
                    width: 220,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: (_similarity.clamp(0, 100) / 100) * 220,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _similarity >= 90
                            ? Colors.greenAccent
                            : _similarity >= 70
                                ? Colors.orangeAccent
                                : Colors.redAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_similarity.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Arahkan wajah ke kamera depan\nPastikan pencahayaan cukup',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.3,
                    ),
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
