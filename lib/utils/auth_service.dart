import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

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
      debugPrint('[AppleSignIn] Authorization error: ${e.code} - ${e.message}');
      rethrow;
    }
    if (appleCredential.identityToken == null) {
      debugPrint('[AppleSignIn] Apple a renvoye une credential sans identityToken');
      throw Exception('Connexion Apple incomplete. Reessayez ou utilisez votre email.');
    }
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
    try {
      return await _auth.signInWithCredential(oauthCredential);
    } on FirebaseAuthException catch (e) {
      // Diagnostic precis pour Apple Review et pour debug en prod.
      // invalid-credential = identityToken refuse par Firebase (config .p8 / Team
      // ID / Key ID errones cote Firebase Console).
      debugPrint('[AppleSignIn] FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'invalid-credential') {
        throw Exception(
          'Connexion Apple temporairement indisponible. '
          'Veuillez utiliser email/mot de passe.',
        );
      }
      rethrow;
    }
  }

  static Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> signOut() async {
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
