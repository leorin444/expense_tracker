import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      await auth.signInWithEmailAndPassword(email: email, password: password);
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
      await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
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
