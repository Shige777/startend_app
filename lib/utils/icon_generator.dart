import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class StartEndIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 背景を白に設定
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// アイコン生成用のヘルパークラス
class IconGenerator {
  static Future<void> generateIcon() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = StartEndIconPainter();

      const size = Size(1024, 1024);
      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      final image = await picture.toImage(1024, 1024);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        // アプリのドキュメントディレクトリに保存
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/app_icon.png');
        await file.writeAsBytes(byteData.buffer.asUint8List());

        print('アイコンが生成されました: ${file.path}');
        print('このファイルを assets/icons/app_icon.png にコピーしてください');
      }
    } catch (e) {
      print('アイコン生成エラー: $e');
    }
  }
}
