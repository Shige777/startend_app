import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // ファイルサイズ制限（5MB）- 圧縮後の制限
  static const int maxFileSizeBytes = 5 * 1024 * 1024;

  // 圧縮設定
  static const int compressionQuality = 85; // 画質（0-100）
  static const int maxWidth = 1920; // 最大幅
  static const int maxHeight = 1080; // 最大高さ

  /// 画像をFirebase Storageにアップロード（自動圧縮付き）
  static Future<String?> uploadImage({
    required String filePath,
    required String userId,
    required String folder, // 'posts', 'profiles', etc.
  }) async {
    try {
      if (kIsWeb) {
        throw UnsupportedError('Web環境ではuploadImageFromBytesメソッドを使用してください');
      }

      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('ファイルが存在しません');
      }

      // ファイルサイズをチェック
      final originalSize = await file.length();
      if (originalSize == 0) {
        throw Exception('ファイルが空です');
      }

      // 画像を圧縮
      final compressedFile = await _compressImage(filePath);
      final compressedSize = await compressedFile.length();

      print(
          '画像圧縮: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB → ${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB');

      // 圧縮後のファイルサイズをチェック
      if (compressedSize > maxFileSizeBytes) {
        throw Exception('圧縮後もファイルサイズが大きすぎます。より小さい画像を選択してください。');
      }

      // ファイルをバイトデータとして読み込み
      final bytes = await compressedFile.readAsBytes();
      print('バイトデータ読み込み完了: ${bytes.length}bytes');

      // より短いファイル名を生成
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final shortUserId = userId.length > 10 ? userId.substring(0, 10) : userId;
      final fileName = '${timestamp}_$shortUserId.jpg';

      // より短いStorage参照を作成
      final storagePath = '$folder/$fileName';
      print('Storage path: $storagePath');

      final ref = _storage.ref().child(storagePath);

      // 最小限のメタデータを設定
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );

      print('アップロード開始: バイトデータから');

      // バイトデータから直接アップロード
      final uploadTask = ref.putData(bytes, metadata);

      // アップロード完了を待機
      final snapshot = await uploadTask;
      print('アップロード完了');

      // ダウンロードURLを取得
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('ダウンロードURL取得完了: ${downloadUrl.length}文字');

      // 一時ファイルを削除
      try {
        if (compressedFile.path != file.path) {
          await compressedFile.delete();
        }
      } catch (e) {
        print('一時ファイル削除エラー: $e');
      }

      return downloadUrl;
    } on FirebaseException catch (e) {
      print('Firebase Storage エラー詳細:');
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Plugin: ${e.plugin}');
      print('  StackTrace: ${e.stackTrace}');
      return _handleFirebaseStorageError(e);
    } catch (e) {
      print('画像アップロードエラー: $e');
      rethrow;
    }
  }

  /// バイトデータから画像をアップロード（Web対応、自動圧縮付き）
  static Future<String?> uploadImageFromBytes({
    required Uint8List bytes,
    required String userId,
    required String folder,
    required String fileName,
  }) async {
    try {
      // 空のファイルをチェック
      if (bytes.isEmpty) {
        throw Exception('ファイルが空です');
      }

      final originalSize = bytes.length;
      print('元のファイルサイズ: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB');

      // 画像を圧縮
      final compressedBytes = await _compressImageFromBytes(bytes, fileName);
      final compressedSize = compressedBytes.length;

      print(
          '画像圧縮: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB → ${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB');

      // 圧縮後のファイルサイズをチェック
      if (compressedSize > maxFileSizeBytes) {
        throw Exception('圧縮後もファイルサイズが大きすぎます。より小さい画像を選択してください。');
      }

      // より短いファイル名を生成
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final shortUserId = userId.length > 10 ? userId.substring(0, 10) : userId;
      final finalFileName = '${timestamp}_$shortUserId.jpg';

      // より短いStorage参照を作成
      final storagePath = '$folder/$finalFileName';
      print('Storage path: $storagePath');

      final ref = _storage.ref().child(storagePath);

      // 最小限のメタデータを設定
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );

      print('アップロード開始: ${compressedBytes.length}bytes');

      // 圧縮した画像をアップロード
      final uploadTask = ref.putData(compressedBytes, metadata);

      // アップロード完了を待機
      final snapshot = await uploadTask;
      print('アップロード完了');

      // ダウンロードURLを取得
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('ダウンロードURL取得完了: ${downloadUrl.length}文字');

      return downloadUrl;
    } on FirebaseException catch (e) {
      print('Firebase Storage エラー詳細:');
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Plugin: ${e.plugin}');
      print('  StackTrace: ${e.stackTrace}');
      return _handleFirebaseStorageError(e);
    } catch (e) {
      print('画像アップロードエラー: $e');
      rethrow;
    }
  }

  /// 画像を圧縮（ファイルパスから）
  static Future<File> _compressImage(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();

      // 1MB以下の場合は圧縮しない
      if (fileSize <= 1024 * 1024) {
        return file;
      }

      // 圧縮設定を決定
      int quality = compressionQuality;
      int maxW = maxWidth;
      int maxH = maxHeight;

      // ファイルサイズに応じて圧縮設定を調整
      if (fileSize > 10 * 1024 * 1024) {
        // 10MB以上
        quality = 70;
        maxW = 1280;
        maxH = 720;
      } else if (fileSize > 5 * 1024 * 1024) {
        // 5MB以上
        quality = 75;
        maxW = 1600;
        maxH = 900;
      }

      // 圧縮実行
      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
        filePath,
        '${filePath}_compressed.jpg',
        quality: quality,
        minWidth: maxW,
        minHeight: maxH,
        format: CompressFormat.jpeg,
      );

      if (compressedXFile == null) {
        throw Exception('画像の圧縮に失敗しました');
      }

      return File(compressedXFile.path);
    } catch (e) {
      print('画像圧縮エラー: $e');
      // 圧縮に失敗した場合は元のファイルを返す
      return File(filePath);
    }
  }

  /// 画像を圧縮（バイトデータから）
  static Future<Uint8List> _compressImageFromBytes(
      Uint8List bytes, String fileName) async {
    try {
      final fileSize = bytes.length;

      // 1MB以下の場合は圧縮しない
      if (fileSize <= 1024 * 1024) {
        return bytes;
      }

      // 圧縮設定を決定
      int quality = compressionQuality;
      int maxW = maxWidth;
      int maxH = maxHeight;

      // ファイルサイズに応じて圧縮設定を調整
      if (fileSize > 10 * 1024 * 1024) {
        // 10MB以上
        quality = 70;
        maxW = 1280;
        maxH = 720;
      } else if (fileSize > 5 * 1024 * 1024) {
        // 5MB以上
        quality = 75;
        maxW = 1600;
        maxH = 900;
      }

      // 圧縮実行
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        minWidth: maxW,
        minHeight: maxH,
        format: CompressFormat.jpeg,
      );

      return compressedBytes;
    } catch (e) {
      print('画像圧縮エラー: $e');
      // 圧縮に失敗した場合は元のバイトデータを返す
      return bytes;
    }
  }

  /// Firebase Storageエラーの統一的な処理
  static String? _handleFirebaseStorageError(FirebaseException e) {
    switch (e.code) {
      case 'object-not-found':
        return null;
      case 'unauthorized':
        throw Exception('アップロード権限がありません');
      case 'canceled':
        throw Exception('アップロードがキャンセルされました');
      case 'unknown':
        if (e.message?.contains('Message too long') == true) {
          throw Exception('ファイルサイズが大きすぎます。画像を圧縮してください。');
        } else if (e.message?.contains('network') == true) {
          throw Exception('ネットワークエラーが発生しました。接続を確認してください。');
        } else {
          throw Exception('アップロードに失敗しました。しばらく待ってから再試行してください。');
        }
      case 'retry-limit-exceeded':
        throw Exception('アップロードがタイムアウトしました。ファイルサイズを小さくしてください。');
      case 'quota-exceeded':
        throw Exception('ストレージ容量が不足しています。');
      default:
        throw Exception('アップロードに失敗しました: ${e.message}');
    }
  }

  /// プロフィール画像をアップロード
  static Future<String?> uploadProfileImage({
    required String filePath,
    required String userId,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web環境ではuploadProfileImageFromBytesを使用してください');
    }
    return uploadImage(
      filePath: filePath,
      userId: userId,
      folder: 'profiles',
    );
  }

  /// プロフィール画像をアップロード（Web用）
  static Future<String?> uploadProfileImageFromBytes({
    required Uint8List bytes,
    required String userId,
    required String fileName,
  }) async {
    return uploadImageFromBytes(
      bytes: bytes,
      userId: userId,
      folder: 'profiles',
      fileName: fileName,
    );
  }

  /// 投稿画像をアップロード
  static Future<String?> uploadPostImage({
    required String filePath,
    required String userId,
    required String postId,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web環境ではuploadPostImageFromBytesを使用してください');
    }
    return uploadImage(
      filePath: filePath,
      userId: userId,
      folder: 'posts',
    );
  }

  /// 投稿画像をアップロード（Web用）
  static Future<String?> uploadPostImageFromBytes({
    required Uint8List bytes,
    required String userId,
    required String postId,
    required String fileName,
  }) async {
    return uploadImageFromBytes(
      bytes: bytes,
      userId: userId,
      folder: 'posts',
      fileName: fileName,
    );
  }

  /// コミュニティアイコンをアップロード
  static Future<String?> uploadCommunityIcon({
    required String filePath,
    required String userId,
    required String communityId,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web環境ではuploadCommunityIconFromBytesを使用してください');
    }
    return uploadImage(
      filePath: filePath,
      userId: userId,
      folder: 'communities',
    );
  }

  /// コミュニティアイコンをアップロード（Web用）
  static Future<String?> uploadCommunityIconFromBytes({
    required Uint8List bytes,
    required String userId,
    required String communityId,
    required String fileName,
  }) async {
    return uploadImageFromBytes(
      bytes: bytes,
      userId: userId,
      folder: 'communities',
      fileName: fileName,
    );
  }

  /// 画像を削除
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      return true;
    } catch (e) {
      print('画像削除エラー: $e');
      return false;
    }
  }

  /// 複数の画像を削除
  static Future<void> deleteImages(List<String> imageUrls) async {
    final futures = imageUrls.map((url) => deleteImage(url));
    await Future.wait(futures);
  }

  /// 画像を圧縮してアップロード（オプション）
  static Future<String?> uploadCompressedImage({
    required String filePath,
    required String userId,
    required String folder,
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1080,
  }) async {
    try {
      // TODO: image_compressorパッケージを使用して画像を圧縮
      // 現在は元の画像をそのままアップロード
      return uploadImage(
        filePath: filePath,
        userId: userId,
        folder: folder,
      );
    } catch (e) {
      print('圧縮画像アップロードエラー: $e');
      return null;
    }
  }

  /// ストレージ使用量を取得
  static Future<int> getStorageUsage(String userId) async {
    try {
      // Firebase Storageには直接的な使用量取得APIがないため、
      // Firestoreで管理するか、Cloud Functionsを使用する必要があります
      // ここでは簡易実装として0を返す
      return 0;
    } catch (e) {
      print('ストレージ使用量取得エラー: $e');
      return 0;
    }
  }
}
