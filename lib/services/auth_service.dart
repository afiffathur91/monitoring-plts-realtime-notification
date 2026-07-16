import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  
  // Login with Firebase
  Future<User?> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        return User(
          id: credential.user!.uid,
          email: credential.user!.email!,
          name: credential.user!.displayName ?? 'Solar Plant Admin',
        );
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
    return null;
  }
  
  // Register with Firebase
  Future<User?> register(String name, String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(name);
        
        return User(
          id: credential.user!.uid,
          email: credential.user!.email!,
          name: name,
        );
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
    return null;
  }
  
  // Get current user
  Future<User?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      return User(
        id: firebaseUser.uid,
        email: firebaseUser.email!,
        name: firebaseUser.displayName ?? 'Solar Plant Admin',
      );
    }
    return null;
  }
  
  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
} 