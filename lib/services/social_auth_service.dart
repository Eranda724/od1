import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Handles Google Sign-In (Android + iOS) and Apple Sign-In (iOS only).
///
/// After a successful sign-in, each method upserts the user's Firestore
/// document so the leaderboard, profile, and friends features work
/// immediately without a separate registration step.
class SocialAuthService {
  SocialAuthService._();

  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  // ── Google Sign-In ──────────────────────────────────────────────────────────

  /// Signs the user in with Google.
  ///
  /// Returns the [UserCredential] on success.
  /// Throws [FirebaseAuthException] on auth errors.
  /// Returns null if the user cancelled the sign-in sheet.
  static Future<UserCredential?> signInWithGoogle() async {
    // Trigger the Google authentication flow
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // user cancelled

    // Obtain auth details
    final googleAuth = await googleUser.authentication;

    // Create a Firebase credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase
    final userCredential = await _auth.signInWithCredential(credential);

    // Upsert Firestore profile (won't overwrite existing data)
    final isNew = userCredential.additionalUserInfo?.isNewUser ?? false;
    await _upsertProfile(userCredential.user, isNewUser: isNew);

    return userCredential;
  }

  // ── Apple Sign-In (iOS only) ────────────────────────────────────────────────

  /// Returns true if Apple Sign-In is available on this device.
  /// Always false on Android.
  static bool get isAppleSignInAvailable => Platform.isIOS;

  /// Signs the user in with Apple (iOS only).
  ///
  /// Returns the [UserCredential] on success.
  /// Returns null if the user cancelled.
  /// Throws on unsupported platform or Firebase error.
  static Future<UserCredential?> signInWithApple() async {
    assert(Platform.isIOS, 'Apple Sign-In is only supported on iOS.');

    // Request Apple credential
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    // Build OAuth credential for Firebase
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    // Sign in to Firebase
    final userCredential = await _auth.signInWithCredential(oauthCredential);

    // Apple only sends the full name on the FIRST sign-in.
    // Construct display name if available.
    final givenName = appleCredential.givenName;
    final familyName = appleCredential.familyName;
    String? displayName;
    if (givenName != null || familyName != null) {
      displayName = [givenName, familyName]
          .where((n) => n != null && n.isNotEmpty)
          .join(' ');
    }

    // Upsert Firestore profile
    final isNew = userCredential.additionalUserInfo?.isNewUser ?? false;
    await _upsertProfile(userCredential.user, isNewUser: isNew, displayNameOverride: displayName);

    return userCredential;
  }

  // ── Re-authentication helpers ───────────────────────────────────────────────

  /// Re-authenticates a Google user. Used before sensitive operations
  /// (e.g., account deletion).
  static Future<void> reauthWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'cancelled',
        message: 'Google sign-in was cancelled.',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.currentUser!.reauthenticateWithCredential(credential);
  }

  /// Re-authenticates an Apple user (iOS only). Used before sensitive
  /// operations (e.g., account deletion).
  static Future<void> reauthWithApple() async {
    assert(Platform.isIOS, 'Apple re-auth is only supported on iOS.');
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    await _auth.currentUser!.reauthenticateWithCredential(oauthCredential);
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  /// Upserts the Firestore user document after social sign-in.
  /// Uses merge so existing fields (streak, scores, etc.) are never lost.
  static Future<void> _upsertProfile(
    User? user, {
    bool isNewUser = false,
    String? displayNameOverride,
  }) async {
    if (user == null) return;

    final data = <String, dynamic>{};

    // Use the override (Apple first login), fall back to Auth displayName
    final name = (displayNameOverride?.isNotEmpty == true)
        ? displayNameOverride!
        : (user.displayName?.isNotEmpty == true ? user.displayName! : null);

    if (name != null) {
      data['displayName'] = name;
      // Keep Firebase Auth profile in sync
      if (user.displayName != name) {
        await user.updateDisplayName(name);
      }
    }

    if (user.email != null) {
      data['email'] = user.email;
    }

    if (isNewUser) {
      data['scores'] = {
        'daily': 0,
        'weekly': 0,
        'monthly': 0,
        'lifetime': 0,
      };
    }

    if (data.isNotEmpty) {
      await _db
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
    }
  }
}
