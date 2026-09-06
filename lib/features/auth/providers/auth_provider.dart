import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_tracker/core/services/api_service.dart';

class AuthProvider with ChangeNotifier {
  FirebaseAuth? _auth;

  FirebaseAuth get auth {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider() {
    auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  // ================= GETTERS =================

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ================= PRIVATE HELPERS =================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      // ── Email / account ──────────────────────────────
      case 'user-not-found':
        return "No account found with this email address. Please register first.";
      case 'email-already-in-use':
        return "This email is already registered. Try logging in instead.";
      case 'invalid-email':
        return "The email address format is invalid. Please check and try again.";
      case 'user-disabled':
        return "This account has been disabled. Please contact support.";

      // ── Password ─────────────────────────────────────
      case 'wrong-password':
        return "Incorrect password. Please try again or reset your password.";
      case 'weak-password':
        return "Password is too weak. Use at least 6 characters with letters and numbers.";

      // ── Session / token ──────────────────────────────
      case 'invalid-credential':
        return "Your email or password is incorrect. Please double-check and try again.";
      case 'credential-already-in-use':
        return "This credential is already linked to another account.";
      case 'requires-recent-login':
        return "This action requires a recent login. Please log out and log in again.";

      // ── Rate limiting ─────────────────────────────────
      case 'too-many-requests':
        return "Too many failed attempts. Your account is temporarily locked. Try again later or reset your password.";

      // ── Network ───────────────────────────────────────
      case 'network-request-failed':
        return "Network error. Please check your internet connection and try again.";

      // ── Fallback ──────────────────────────────────────
      default:
        return "Authentication error (${e.code}). Please try again.";
    }
  }

  // ================= AUTH METHODS =================

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);

    try {
      final credential = await auth.signInWithEmailAndPassword(email: email, password: password);
      
      // Upsert user in live server DB
      if (credential.user != null) {
        try {
          final apiService = ApiService();
          await apiService.post('/auth/login-sync', body: {
            'email': credential.user!.email ?? email,
            'firebaseUid': credential.user!.uid,
            'lastLoginAt': DateTime.now().toIso8601String(),
          }).timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('API login sync note: $e');
        }
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e));
      return false;
    } catch (_) {
      _setError("Something went wrong. Try again.");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(String email, String password) async {
    _setLoading(true);
    _setError(null);

    try {
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user to SSMS database via API
      if (userCredential.user != null) {
        try {
          final apiService = ApiService();
          await apiService.post('/auth/register', body: {
            'email': email,
            'password': password,
            'firebaseUid': userCredential.user!.uid,
          });
        } catch (e) {
          // Log error but don't fail auth if API fails
          debugPrint('Failed to save user to API: $e');
        }
      }

      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e));
      return false;
    } catch (_) {
      _setError("Something went wrong. Try again.");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await auth.signOut();
    _user = null;
    notifyListeners();
  }

  /// Ensure current logged in user is synced/registered in the backend database
  Future<bool> syncUserToDatabase() async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;

    try {
      final apiService = ApiService();
      await apiService.post('/auth/register', body: {
        'email': currentUser.email ?? '',
        'password': 'AppUser_${currentUser.uid.substring(0, 8)}',
        'firebaseUid': currentUser.uid,
      });
      return true;
    } on ApiException catch (e) {
      // If user already exists in DB (409 conflict or duplicate message), it is synced
      if (e.statusCode == 409 ||
          e.message.toLowerCase().contains('already exists') ||
          e.message.toLowerCase().contains('registered')) {
        return true;
      }
      debugPrint('User sync to DB warning: $e');
      return false;
    } catch (e) {
      debugPrint('User sync to DB failed: $e');
      return false;
    }
  }

  // ================= FORGOT PASSWORD =================

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      await auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e));
      return false;
    } catch (_) {
      _setError("Something went wrong. Try again.");
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
