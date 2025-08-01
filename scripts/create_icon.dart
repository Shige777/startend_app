import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

void main() async {
  // Flutterの初期化
  WidgetsFlutterBinding.ensureInitialized();

  // アイコン生成
  await generateStartEndIcon();
}

Future<void> generateStartEndIcon() async {
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const size = Size(1024, 1024);

    // 背景を白に設定
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // テキストスタイルを設定
    const textStyle = TextStyle(
      color: Colors.black,
      fontSize: 120,
      fontWeight: FontWeight.bold,
      fontFamily: 'Arial',
    );

    // テキストを描画
    final textSpan = TextSpan(text: 'StartEnd', style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // テキストを中央に配置
    final offset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );

    textPainter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final image = await picture.toImage(1024, 1024);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      // assets/icons/app_icon.png に保存
      final file = File('assets/icons/app_icon.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      print('✅ StartEndアイコンが生成されました: ${file.path}');
      print('📱 アイコン生成を実行してください: flutter pub run flutter_launcher_icons:main');
    }
  } catch (e) {
    print('❌ アイコン生成エラー: $e');
  }
}
