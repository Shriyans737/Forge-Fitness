import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({this.firebaseAuth});

  static bool isFirebaseInitialized = false;

  final FirebaseAuth? firebaseAuth;

  FirebaseAuth get _auth => firebaseAuth ?? FirebaseAuth.instance;

  String? get currentUid => isFirebaseInitialized ? _auth.currentUser?.uid : null;

  Future<String> signInAnonymouslyIfNeeded() async {
    if (!isFirebaseInitialized) {
      throw FirebaseAuthException(
        code: 'firebase-not-initialized',
        message: 'Firebase is unavailable.',
      );
    }
    final currentUser = _auth.currentUser;
    if (currentUser != null) return currentUser.uid;

    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'anonymous-sign-in-failed',
        message: 'Anonymous sign-in did not return a user.',
      );
    }
    return user.uid;
  }
}
