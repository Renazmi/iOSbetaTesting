import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_sync_service.dart';
import '../utils/firebase_action_link.dart';

class StudentRegistrationVerificationService {
  Future<RegistrationSendResult> sendGmailVerification({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) {
      return RegistrationSendResult.fail('Gmail and password are required before verification.');
    }

    try {
      await _ensureFirebaseReady();
      final auth = FirebaseAuth.instance;
      await auth.signOut();

      User? user;
      try {
        final credential = await auth.createUserWithEmailAndPassword(
          email: normalized,
          password: password,
        );
        user = credential.user;
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use') {
          return RegistrationSendResult.fail(_mapAuthError(error));
        }

        final existing = await auth.signInWithEmailAndPassword(
          email: normalized,
          password: password,
        );
        user = existing.user;
        if (user?.emailVerified == true) {
          await auth.signOut();
          return RegistrationSendResult.fail(
            'This Gmail is already verified in Firebase. Sign in or use a different Gmail.',
          );
        }
      }

      if (user == null) {
        return const RegistrationSendResult.fail('Could not prepare Gmail verification.');
      }

      await user.sendEmailVerification(
        ActionCodeSettings(
          url: 'https://trackit-fac8a.firebaseapp.com/',
          handleCodeInApp: true,
          androidPackageName: 'com.trackit.trackit_mobile',
          androidInstallApp: true,
          androidMinimumVersion: '1',
        ),
      );
      await auth.signOut();
      return const RegistrationSendResult.ok();
    } on FirebaseAuthException catch (error) {
      return RegistrationSendResult.fail(_mapAuthError(error));
    } catch (_) {
      return const RegistrationSendResult.fail(
        'Could not send verification email. Check your connection and try again.',
      );
    }
  }

  Future<RegistrationVerifyResult> verifyGmailLink({
    required String code,
    required String expectedEmail,
  }) async {
    final oobCode = parseFirebaseOobCode(code);
    final email = expectedEmail.trim().toLowerCase();
    if (oobCode == null) {
      return const RegistrationVerifyResult.fail(
        'Paste the verification link from your Gmail, or copy the code from that link.',
      );
    }
    if (email.isEmpty) {
      return const RegistrationVerifyResult.fail('Enter your Gmail address.');
    }

    try {
      await _ensureFirebaseReady();
      final auth = FirebaseAuth.instance;
      final info = await auth.checkActionCode(oobCode);
      final verifiedEmail = '${info.data['email'] ?? ''}'.trim().toLowerCase();
      if (verifiedEmail.isEmpty || verifiedEmail != email) {
        return const RegistrationVerifyResult.fail(
          'This verification link does not match the Gmail address you entered.',
        );
      }
      await auth.applyActionCode(oobCode);
      await auth.signOut();
      return const RegistrationVerifyResult.ok();
    } on FirebaseAuthException catch (error) {
      return RegistrationVerifyResult.fail(_mapAuthError(error));
    } catch (_) {
      return const RegistrationVerifyResult.fail(
        'Could not verify Gmail. Check your connection and try again.',
      );
    }
  }

  Future<void> _ensureFirebaseReady() async {
    if (!FirestoreSyncService.instance.isReady) {
      await FirestoreSyncService.instance.initialize();
    }
  }

  String _mapAuthError(FirebaseAuthException error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid Gmail address.';
      case 'email-already-in-use':
        return 'This Gmail is already registered. Try signing in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'wrong-password':
        return 'Could not verify this Gmail with the password you entered.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      case 'expired-action-code':
        return 'This verification link has expired. Request a new verification email.';
      case 'invalid-action-code':
        return 'Invalid verification link or code. Request a new verification email.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      default:
        return 'Something went wrong. Try again.';
    }
  }
}

class RegistrationSendResult {
  const RegistrationSendResult._({required this.success, this.error});

  const RegistrationSendResult.ok() : this._(success: true);
  const RegistrationSendResult.fail(String message) : this._(success: false, error: message);

  final bool success;
  final String? error;
}

class RegistrationVerifyResult {
  const RegistrationVerifyResult._({required this.valid, this.error});

  const RegistrationVerifyResult.ok() : this._(valid: true);
  const RegistrationVerifyResult.fail(String message) : this._(valid: false, error: message);

  final bool valid;
  final String? error;
}
