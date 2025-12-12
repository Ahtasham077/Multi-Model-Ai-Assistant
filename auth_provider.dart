// lib/providers/auth_provider.dart
// Application Logic: Authentication and User State

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  final fba.FirebaseAuth _auth = fba.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoggedIn = false;
  bool _isLoading = true;
  User? _currentUser;
  final Uuid _uuid = const Uuid();

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  User? get currentUser => _currentUser;

  Future<void> checkLoginStatus() async {
    try {
      final firebaseUser = _auth.currentUser;

      if (firebaseUser != null) {
        _currentUser = User(
          id: firebaseUser.uid,
          email: firebaseUser.email!,
          name: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
          createdAt: DateTime.now(),
        );
        _isLoggedIn = true;
      } else {
        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

        // Check local non-Firebase session (used for Guest/Web persistence)
        if (isLoggedIn) {
          final email = prefs.getString('user_email');
          final name = prefs.getString('user_name');
          final userId = prefs.getString('user_id');
          final createdAt = prefs.getString('user_createdAt');

          if (email != null && name != null) {
            _currentUser = User(
              id: userId ?? _uuid.v4(),
              email: email,
              name: name,
              createdAt: createdAt != null
                  ? DateTime.parse(createdAt)
                  : DateTime.now(),
            );
            _isLoggedIn = true;
          }
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking login: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    try {
      _isLoading = true;
      notifyListeners();

      final fba.UserCredential result =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await result.user!.updateDisplayName(name);
      await _saveLocalUser(result.user!);

      _currentUser = User(
        id: result.user!.uid,
        email: email,
        name: name,
        createdAt: DateTime.now(),
      );

      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final fba.UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await _saveLocalUser(result.user!);

      _currentUser = User(
        id: result.user!.uid,
        email: email,
        name: result.user!.displayName ?? result.user!.email!.split('@')[0],
        createdAt: DateTime.now(),
      );

      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final fba.AuthCredential credential = fba.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final fba.UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final displayName = userCredential.user!.displayName ??
          userCredential.user!.email!.split('@')[0];

      if (userCredential.user!.displayName == null) {
        await userCredential.user!.updateDisplayName(displayName);
      }

      await _saveLocalUser(userCredential.user!);

      _currentUser = User(
        id: userCredential.user!.uid,
        email: userCredential.user!.email!,
        name: displayName,
        createdAt: DateTime.now(),
      );

      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);

      _isLoggedIn = false;
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }

  Future<void> _saveLocalUser(fba.User firebaseUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('user_id', firebaseUser.uid);
    await prefs.setString('user_email', firebaseUser.email!);
    await prefs.setString('user_name',
        firebaseUser.displayName ?? firebaseUser.email!.split('@')[0]);
    await prefs.setString('user_createdAt', DateTime.now().toIso8601String());
  }
}
