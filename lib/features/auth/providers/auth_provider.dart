import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get user => _user;

  bool get isLoggedIn => _user != null;

  bool get isLoading => _isLoading;

  String? get error => _error;

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _user = _auth.currentUser;
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = "An unexpected error occurred";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register a new user with email and password
  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = _auth.currentUser;
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = "An unexpected error occurred";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logout current user
  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }
}
