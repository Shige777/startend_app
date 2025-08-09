
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  // Firebase初期化（実際のプロジェクトでは適切に設定）
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  try {
    // デモアカウント作成
    final userCredential = await auth.createUserWithEmailAndPassword(
      email: 'demo@startend.app',
      password: 'Demo123!',
    );

    if (userCredential.user != null) {
      // ユーザープロフィール作成
      await firestore.collection('users').doc(userCredential.user!.uid).set({
        'id': userCredential.user!.uid,
        'email': 'demo@startend.app',
        'displayName': 'デモユーザー',
        'bio': 'これは審査用のデモアカウントです。',
        'profileImageUrl': '',
        'followerIds': [],
        'followingIds': [],
        'communityIds': [],
        'postCount': 0,
        'isPrivate': false,
        'requiresApproval': false,
        'showCommunityPostsToOthers': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('デモアカウントが正常に作成されました:');
      print('メールアドレス: demo@startend.app');
      print('パスワード: Demo123!');
      print('ユーザーID: ${userCredential.user!.uid}');
    }
  } catch (e) {
    print('デモアカウント作成エラー: $e');
  }
}
