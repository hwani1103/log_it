import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('=============== 네트워크 요청!! ===============');
      print('🔐 [Auth] Google 로그인 시작');
      print('===========================================');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('⚠️ [Auth] 사용자가 로그인 취소');
        return null;
      }

      print('📱 [Auth] Google 계정 인증 중...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔄 [Auth] Firebase 인증 중...');
      final result = await _auth.signInWithCredential(credential);

      print('✅ [Auth] 로그인 성공 (${result.user?.email})');
      return result;
    } catch (e) {
      print('❌ [Auth] 로그인 실패: $e');
      print('===========================================');
      return null;
    }
  }

  Future<void> signOut() async {
    print('=============== 네트워크 요청!! ===============');
    print('🔓 [Auth] 로그아웃');
    print('===========================================');

    await _googleSignIn.signOut();
    await _auth.signOut();

    print('✅ [Auth] 로그아웃 완료');
  }
}
