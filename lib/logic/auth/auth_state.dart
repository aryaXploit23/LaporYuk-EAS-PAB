import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User? firebaseUser;
  final String email;
  final String fullName;
  final String phone;
  final String address;
  final String role; // 'Warga' atau 'Petugas'

  AuthAuthenticated({
    this.firebaseUser,
    required this.email,
    this.fullName = '',
    this.phone = '',
    this.address = '',
    this.role = 'Warga',
  });
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
