import 'dart:typed_data';
import 'package:flutter/material.dart';

class PlatformImagePickerWidget extends StatelessWidget {
  final Function(Uint8List, String) onImageSelected;
  final double? width;
  final double? height;
  final String? placeholder;

  const PlatformImagePickerWidget({
    super.key,
    required this.onImageSelected,
    this.width,
    this.height,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Center(
        child: Text(
          'このプラットフォームでは画像選択はサポートされていません',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
