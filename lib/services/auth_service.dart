import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  static const String driveFileScope =
      'https://www.googleapis.com/auth/drive.file';

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', driveFileScope],
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  GoogleSignIn get googleSignIn => _googleSignIn;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'google-signin-cancelled',
          message: 'Google sign-in was cancelled.',
        );
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw FirebaseAuthException(
          code: 'google-signin-no-token',
          message: 'Google sign-in did not return authentication tokens.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return _auth.signInWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } on PlatformException catch (error) {
      throw _mapGooglePlatformException(error);
    } catch (error) {
      throw FirebaseAuthException(
        code: 'google-signin-failed',
        message: 'Google sign-in failed: $error',
      );
    }
  }

  Future<GoogleSignInAccount?> getSignedInGoogleAccount() async {
    final signedIn = _googleSignIn.currentUser;
    if (signedIn != null) return signedIn;
    return _googleSignIn.signInSilently();
  }

  Future<void> ensureDriveAccess() async {
    final account = await getSignedInGoogleAccount();
    if (account == null) {
      throw FirebaseAuthException(
        code: 'auth-required',
        message: 'Sign in with Google to sync notes to Drive.',
      );
    }

    var hasDriveScope = false;
    try {
      hasDriveScope = await _googleSignIn.canAccessScopes([driveFileScope]);
    } on UnimplementedError {
      // Not implemented on all google_sign_in platform plugins (for example Android).
      hasDriveScope = false;
    } on MissingPluginException {
      hasDriveScope = false;
    } on PlatformException catch (error) {
      throw _mapGooglePlatformException(error);
    }

    if (hasDriveScope) return;

    try {
      final granted = await _googleSignIn.requestScopes([driveFileScope]);
      if (granted) return;
    } on UnimplementedError {
      return;
    } on MissingPluginException {
      return;
    } on PlatformException catch (error) {
      throw _mapGooglePlatformException(error);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore Google sign-out errors and keep Firebase sign-out as source of truth.
    }
  }

  String mapAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email. Use the original sign-in method.';
        case 'operation-not-allowed':
          return 'Google sign-in is not enabled in Firebase Authentication.';
        case 'google-signin-cancelled':
          return 'Google sign-in cancelled.';
        case 'google-signin-no-token':
          return 'Google sign-in did not return a valid token. Please try again.';
        case 'google-signin-config-error':
          return 'Google Sign-In is not configured for Android. Add SHA-1/SHA-256 in Firebase and download a new google-services.json.';
        case 'google-signin-failed':
          return error.message ?? 'Google sign-in failed. Please try again.';
        case 'auth-required':
          return 'Sign in with Google first.';
        case 'drive-access-required':
          return 'Google Drive access is required to sync notes.';
        default:
          return error.message ?? 'Authentication failed. Please try again.';
      }
    }

    return 'Something went wrong. Please try again.';
  }

  FirebaseAuthException _mapGooglePlatformException(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();

    if (code == GoogleSignIn.kSignInCanceledError ||
        code == 'sign_in_cancelled' ||
        code == 'canceled') {
      return FirebaseAuthException(
        code: 'google-signin-cancelled',
        message: 'Google sign-in was cancelled.',
      );
    }

    if (code == GoogleSignIn.kNetworkError || message.contains('network')) {
      return FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Network error while signing in with Google.',
      );
    }

    if (code == GoogleSignIn.kSignInRequiredError ||
        code == 'sign_in_required') {
      return FirebaseAuthException(
        code: 'auth-required',
        message: 'Sign in with Google to sync notes to Drive.',
      );
    }

    if (_isGoogleConfigurationError(code: code, message: message)) {
      return FirebaseAuthException(
        code: 'google-signin-config-error',
        message:
            'Google Sign-In is misconfigured for this Android app. Add SHA-1 and SHA-256 fingerprints for com.example.my_app in Firebase, then replace google-services.json.',
      );
    }

    return FirebaseAuthException(
      code: 'google-signin-failed',
      message: error.message ?? 'Google sign-in failed.',
    );
  }

  bool _isGoogleConfigurationError({
    required String code,
    required String message,
  }) {
    return code == 'developer_error' ||
        message.contains('apiexception: 10') ||
        message.contains('status code: 10') ||
        message.contains('developer error') ||
        message.contains('12500');
  }
}
