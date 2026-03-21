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

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return "No account found with this email";
      case 'wrong-password':
        return "Incorrect password";
      case 'email-already-in-use':
        return "Email is already registered";
      case 'invalid-email':
        return "Invalid email format";
      case 'weak-password':
        return "Password should be at least 6 characters";
      default:
        return "Authentication failed. Please try again";
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
}
