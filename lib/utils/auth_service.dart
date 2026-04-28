import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    debugPrint('Google Sign-In: idToken null? ${googleAuth.idToken == null}');
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  static Future<UserCredential?> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);
    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
    if (appleCredential.identityToken == null) {
      throw Exception('Apple n\'a pas renvoyé d\'identityToken');
    }
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
    return await _auth.signInWithCredential(oauthCredential);
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Supprime le compte Firebase de l'utilisateur courant.
  /// Conformité Google Play : les utilisateurs doivent pouvoir supprimer leur
  /// compte depuis l'app. Retourne `true` si la suppression a réussi,
  /// `false` si aucun utilisateur connecté, `'reauth'` si Firebase exige
  /// une ré-authentification récente avant la suppression.
  static Future<Object> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.delete();
      try { await _googleSignIn.signOut(); } catch (_) {}
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') return 'reauth';
      debugPrint('Delete account erreur : ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Delete account erreur : $e');
      return false;
    }
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
