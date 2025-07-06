import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class PlatformImagePickerWidget extends StatefulWidget {
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
  State<PlatformImagePickerWidget> createState() =>
      _PlatformImagePickerWidgetState();
}

class _PlatformImagePickerWidgetState extends State<PlatformImagePickerWidget> {
  Uint8List? _imageBytes;
  String? _fileName;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _imageBytes != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _imageBytes!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: _clearImage,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.placeholder ?? '画像を選択',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // File input要素を作成
      final html.FileUploadInputElement uploadInput =
          html.FileUploadInputElement();
      uploadInput.accept = 'image/*';
      uploadInput.click();

      uploadInput.onChange.listen((e) async {
        final files = uploadInput.files;
        if (files!.isEmpty) {
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final file = files[0];
        _fileName = file.name;

        // ファイルを読み込み
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);

        reader.onLoadEnd.listen((e) async {
          try {
            final Uint8List originalBytes = reader.result as Uint8List;

            // 画像をリサイズ
            final Uint8List resizedBytes = await _resizeImage(
              originalBytes,
              maxWidth: 1920,
              maxHeight: 1080,
              quality: 0.8,
            );

            setState(() {
              _imageBytes = resizedBytes;
              _isLoading = false;
            });

            // コールバックを呼び出し
            widget.onImageSelected(resizedBytes, _fileName!);
          } catch (e) {
            print('画像処理エラー: $e');
            setState(() {
              _isLoading = false;
            });
          }
        });
      });
    } catch (e) {
      print('画像選択エラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Uint8List> _resizeImage(
    Uint8List imageBytes, {
    required int maxWidth,
    required int maxHeight,
    required double quality,
  }) async {
    try {
      // HTML Canvas要素を作成
      final html.CanvasElement canvas = html.CanvasElement();
      final html.CanvasRenderingContext2D ctx =
          canvas.getContext('2d') as html.CanvasRenderingContext2D;

      // Image要素を作成してデータを読み込み
      final html.ImageElement img = html.ImageElement();
      final String dataUrl =
          'data:image/jpeg;base64,${_uint8ListToBase64(imageBytes)}';

      img.src = dataUrl;

      // 画像の読み込み完了を待機
      await img.onLoad.first;

      // リサイズ後のサイズを計算
      final double aspectRatio = img.width! / img.height!;
      int newWidth = img.width!;
      int newHeight = img.height!;

      if (newWidth > maxWidth) {
        newWidth = maxWidth;
        newHeight = (newWidth / aspectRatio).round();
      }

      if (newHeight > maxHeight) {
        newHeight = maxHeight;
        newWidth = (newHeight * aspectRatio).round();
      }

      // Canvasのサイズを設定
      canvas.width = newWidth;
      canvas.height = newHeight;

      // 画像をCanvasに描画
      ctx.drawImageScaled(img, 0, 0, newWidth, newHeight);

      // CanvasからBlob形式で画像データを取得
      final html.Blob blob = await canvas.toBlob('image/jpeg', quality);

      // BlobをUint8Listに変換
      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      await reader.onLoadEnd.first;

      return reader.result as Uint8List;
    } catch (e) {
      print('画像リサイズエラー: $e');
      return imageBytes; // エラー時は元の画像を返す
    }
  }

  String _uint8ListToBase64(Uint8List bytes) {
    String base64String = '';
    for (int i = 0; i < bytes.length; i++) {
      base64String += String.fromCharCode(bytes[i]);
    }
    return html.window.btoa(base64String);
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _fileName = null;
    });
  }
}
