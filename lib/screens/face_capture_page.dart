import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/face_structure_service.dart';
import '../services/db_service.dart';
import '../theme.dart';

class FaceCapturePage extends StatefulWidget {
  final String email;
  const FaceCapturePage({super.key, required this.email});

  @override
  State<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends State<FaceCapturePage> {
  CameraController? _controller;
  XFile? _firstShot;
  XFile? _secondShot;
  bool _processing = false;
  int _step = 1; // indikator langkah
  final _faceService = FaceStructureService();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      // 🔹 Cari kamera depan, kalau tidak ada pakai kamera pertama
      CameraDescription camera;
      if (cameras.any((c) => c.lensDirection == CameraLensDirection.front)) {
        camera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
      } else {
        camera = cameras.first;
        debugPrint('⚠️ Tidak ada kamera depan, pakai kamera belakang.');
      }

      _controller = CameraController(camera, ResolutionPreset.medium);
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Gagal inisialisasi kamera: $e');
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceService.close();
    super.dispose();
  }

  // ========================= CAPTURE FOTO =========================
  Future<void> _capture() async {
    if (!(_controller?.value.isInitialized ?? false)) return;

    try {
      final pic = await _controller!.takePicture();

      if (_step == 1) {
        setState(() {
          _firstShot = pic;
          _step = 2;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto 1 disimpan. Sekarang ambil foto 2 (toleh).'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _secondShot = pic);
        await _save();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto: $e')),
      );
    }
  }

  // ========================= SIMPAN =========================
  Future<void> _save() async {
    if (_firstShot == null || _secondShot == null) return;

    setState(() => _processing = true);
    final bytesA = await File(_firstShot!.path).readAsBytes();
    final bytesB = await File(_secondShot!.path).readAsBytes();

    final structA = await _faceService.extractStructure(bytesA);
    final structB = await _faceService.extractStructure(bytesB);

    if (structA == null || structA.isEmpty || structB == null || structB.isEmpty) {
      _showDialog(
        title: 'Wajah Tidak Valid',
        message: 'Pastikan wajah terlihat jelas dan hanya satu orang di kamera.',
        isError: true,
      );
      setState(() => _processing = false);
      return;
    }

    final live = _faceService.evaluateLiveness(baseline: structA, action: structB);
    if (!live) {
      _showDialog(
        title: 'Tidak Terdeteksi',
        message: 'Silakan toleh sedikit kepala.',
        isError: true,
      );
      setState(() => _processing = false);
      return;
    }

    await DBService.saveFaceStructure(
      email: widget.email,
      structure: structA,
      imageBytes: bytesA,
    );

    setState(() => _processing = false);
    _showDialog(
      title: 'Berhasil!',
      message: 'Struktur wajah berhasil disimpan.',
      isError: false,
      onConfirm: () => Navigator.pop(context, true),
    );
  }

  // ========================= DIALOG RESPONSIF =========================
  void _showDialog({
    required String title,
    required String message,
    required bool isError,
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isError,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: AlertDialog(
            backgroundColor: const Color(0xFFF8F4FF),
            elevation: 10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            title: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                  color: isError ? Colors.redAccent : kPrimary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            actionsPadding: const EdgeInsets.only(right: 12, bottom: 8),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm?.call();
                },
                child: Text(
                  isError ? 'Coba Lagi' : 'OK',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isError ? Colors.redAccent : kPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================= UI =========================
  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Detection Capture'),
        backgroundColor: const Color.fromARGB(255, 225, 205, 245),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          CameraPreview(_controller!),

          // 🌙 Overlay gradient lembut
          Container(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    _step == 1
                        ? 'assets/face_detect.json'
                        : 'assets/face_detect.json',
                    height: 180,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _step == 1
                        ? 'Arahkan wajah Anda ke kamera.\nPastikan wajah terlihat jelas.'
                        : 'Sekarang, toleh sedikit kepala.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (!_processing)
                    ElevatedButton.icon(
                      onPressed: _capture,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(
                        _step == 1 ? 'Ambil Foto Pertama' : 'Ambil Foto Kedua',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: kPrimary,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 36, vertical: 14),
                      ),
                    )
                  else
                    Column(
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 12),
                        Text(
                          'Menyimpan wajah...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // 🪄 Label langkah di kanan atas
          Positioned(
            top: 24,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Langkah $_step dari 2',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
