import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// プラットフォーム別のimport
import 'platform_image_picker_stub.dart'
    if (dart.library.html) 'platform_image_picker_web.dart'
    if (dart.library.io) 'platform_image_picker_mobile.dart';

class PlatformImagePicker extends StatelessWidget {
  final Function(Uint8List, String) onImageSelected;
  final double? width;
  final double? height;
  final String? placeholder;

  const PlatformImagePicker({
    super.key,
    required this.onImageSelected,
    this.width,
    this.height,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformImagePickerWidget(
      onImageSelected: onImageSelected,
      width: width,
      height: height,
      placeholder: placeholder,
    );
  }
}
