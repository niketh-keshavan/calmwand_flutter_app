import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication service for user login/logout
/// Users are created by admin in Firebase Console
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  User? _user;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;
  
  AuthService() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }
  
  /// Initialize - check if user is already logged in
  Future<void> initialize() async {
    _user = _auth.currentUser;
    notifyListeners();
  }
  
  /// Login with email and password
  /// Returns true if successful, false otherwise
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      _user = credential.user;
      _isLoading = false;
      _error = null;
      
      // Save email for convenience
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_email', email.trim());
      
      notifyListeners();
      print('✅ Login successful for ${_user?.email}');
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _error = _getErrorMessage(e.code);
      notifyListeners();
      print('❌ Login failed: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Login failed: $e';
      notifyListeners();
      print('❌ Login failed: $e');
      return false;
    }
  }
  
  /// Logout current user
  Future<void> logout() async {
    try {
      await _auth.signOut();
      _user = null;
      _error = null;
      notifyListeners();
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout failed: $e');
    }
  }
  
  /// Get last used email
  Future<String?> getLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_email');
  }
  
  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// Convert Firebase error codes to user-friendly messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-credential':
        return 'Invalid email or password';
      default:
        return 'Login failed. Please try again';
    }
  }
}
