import 'package:flutter/material.dart';

class SafeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover, // ✅ BoxFit sudah di-handle dengan default value
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl.isNotEmpty ? imageUrl : '',
      height: height,
      width: width,
      fit: fit, // ✅ error hilang karena parameter sudah didefinisikan
      errorBuilder: (_, __, ___) {
        return Container(
          color: Colors.grey.shade200,
          height: height,
          width: width,
          alignment: Alignment.center,
          child: const Icon(Icons.person, size: 40, color: Colors.grey),
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.grey.shade100,
          height: height,
          width: width,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}
