import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'social_auth_service.dart';

/// Handles full account deletion for all auth providers
/// (email/password, Google, Apple).
///
/// Deletion order:
///   1. Re-authenticate (required by Firebase before delete)
///   2. Delete users/{uid}/exercises/* sub-collection
///   3. Delete friendRequests where fromUid == uid
///   4. Delete friendRequests where toUid == uid
///   5. Delete friendPairs where uids contains uid
///   6. Delete users/{uid} document
///   7. Delete Firebase Auth record
///
/// NOTE: Sub-collection deletion is performed document-by-document from the
/// client. If the app crashes mid-deletion, orphaned exercise documents may
/// remain in `users/{uid}/exercises/*`. They are inaccessible to other users
/// per Firestore security rules and have no UX impact. A server-side Cloud
/// Function is the clean solution at scale (documented for client handover).
class AccountDeletionService {
  AccountDeletionService._();

  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  /// Returns the primary provider ID for the current user.
  /// e.g. 'password', 'google.com', 'apple.com'
  static String? get currentProviderType {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : null;
  }

  /// Returns true if the current user signed in with email + password.
  static bool get isEmailPasswordUser => currentProviderType == 'password';

  /// Permanently deletes the current user's account and all associated data.
  ///
  /// [password] — required only for email/password users.
  ///              Pass null for Google or Apple users (re-auth is handled
  ///              via the provider's own flow).
  ///
  /// Throws [FirebaseAuthException] on wrong password, cancelled sign-in,
  /// or other auth errors.
  static Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    final uid = user.uid;
    final provider = currentProviderType;

    // Step 1: Re-authenticate
    switch (provider) {
      case 'password':
        if (password == null || password.isEmpty) {
          throw FirebaseAuthException(
            code: 'invalid-credential',
            message: 'Password is required.',
          );
        }
        if (user.email == null) throw Exception('User has no email address.');
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        break;

      case 'google.com':
        await SocialAuthService.reauthWithGoogle();
        break;

      case 'apple.com':
        await SocialAuthService.reauthWithApple();
        break;

      default:
        throw Exception('Unsupported sign-in provider: $provider');
    }

    // Step 2: Delete users/{uid}/exercises/* sub-collection
    await _deleteSubCollection(
      _db.collection('users').doc(uid).collection('exercises'),
    );

    // Step 3: Delete friendRequests where fromUid == uid
    await _deleteQueryResults(
      _db.collection('friendRequests').where('fromUid', isEqualTo: uid),
    );

    // Step 4: Delete friendRequests where toUid == uid
    await _deleteQueryResults(
      _db.collection('friendRequests').where('toUid', isEqualTo: uid),
    );

    // Step 5: Delete friendPairs where uids contains uid
    await _deleteQueryResults(
      _db.collection('friendPairs').where('uids', arrayContains: uid),
    );

    // Step 6: Delete users/{uid} document
    await _db.collection('users').doc(uid).delete();

    // Step 7: Delete Firebase Auth record (must be last)
    await _auth.currentUser!.delete();
  }

  /// Deletes all documents returned by [query].
  static Future<void> _deleteQueryResults(Query query) async {
    final snap = await query.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  /// Deletes all documents in [collectionRef].
  static Future<void> _deleteSubCollection(
      CollectionReference collectionRef) async {
    await _deleteQueryResults(collectionRef);
  }
}
