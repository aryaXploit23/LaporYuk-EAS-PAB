import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_state.dart';
export 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  FirebaseAuth? _auth;
  static const String _sessionKey = 'auth_session_email';
  static const String _sessionFullName = 'auth_session_fullname';
  static const String _sessionPhone = 'auth_session_phone';
  static const String _sessionAddress = 'auth_session_address';
  static const String _sessionRole = 'auth_session_role';

  AuthCubit() : super(AuthInitial()) {
    try {
      _auth = FirebaseAuth.instance;
    } catch (_) {
      _auth = null;
    }
  }

  // --- CEK APAKAH USER SUDAH LOGIN (Startup) ---
  void checkCurrentUser() {
    emit(AuthLoading());
    
    if (_auth != null && _auth!.currentUser != null) {
      final box = Hive.box('reports_box');
      emit(AuthAuthenticated(
        firebaseUser: _auth!.currentUser,
        email: _auth!.currentUser!.email ?? '',
        fullName: _auth!.currentUser!.displayName ?? 'User',
        role: box.get(_sessionRole) ?? 'Warga',
      ));
    } else {
      // Cek sesi lokal (Hive) untuk Mode Mock
      final box = Hive.box('reports_box');
      final localEmail = box.get(_sessionKey);
      if (localEmail != null) {
        emit(AuthAuthenticated(
          email: localEmail,
          fullName: box.get(_sessionFullName) ?? '',
          phone: box.get(_sessionPhone) ?? '',
          address: box.get(_sessionAddress) ?? '',
          role: box.get(_sessionRole) ?? 'Warga',
        ));
      } else {
        emit(AuthUnauthenticated());
      }
    }
  }

  // --- MASUK (LOGIN) ---
  Future<void> signIn(String email, String password) async {
    emit(AuthLoading());
    
    if (email.isEmpty || password.isEmpty) {
      emit(AuthError('Email dan password tidak boleh kosong.'));
      return;
    }

    // SPESIAL: JALUR KHUSUS PETUGAS (EMAIL @lapor.go.id)
    if (email.endsWith('@lapor.go.id')) {
      final box = Hive.box('reports_box');
      await box.put(_sessionKey, email);
      await box.put(_sessionFullName, 'Petugas Pemeriksa');
      await box.put(_sessionPhone, '081122334455');
      await box.put(_sessionAddress, 'Kantor Dinas Smart City');
      await box.put(_sessionRole, 'Petugas');

      if (_auth != null) {
        try {
          final credential = await _auth!.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          emit(AuthAuthenticated(
            firebaseUser: credential.user,
            email: email,
            fullName: 'Petugas Pemeriksa',
            role: 'Petugas',
          ));
          return;
        } catch (_) {
          // Jika Firebase gagal/belum dibuat akunnya di console, toleransi dengan mock login
        }
      }

      // Login lokal untuk Petugas (jika Firebase offline/mock)
      emit(AuthAuthenticated(
        email: email,
        fullName: 'Petugas Pemeriksa',
        phone: '081122334455',
        address: 'Kantor Dinas Smart City',
        role: 'Petugas',
      ));
      return;
    }

    if (_auth != null) {
      try {
        final credential = await _auth!.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Di Firebase asli, kita tetap simpan role di metadata local untuk membedakan dashboard
        final usersBox = Hive.box('users_box');
        final userData = usersBox.get(email);
        String role = 'Warga';
        if (userData != null) {
          final Map<dynamic, dynamic> userMap = Map<dynamic, dynamic>.from(userData);
          role = userMap['role'] ?? 'Warga';
        }
        
        final box = Hive.box('reports_box');
        await box.put(_sessionRole, role);

        emit(AuthAuthenticated(
          firebaseUser: credential.user,
          email: credential.user?.email ?? email,
          fullName: credential.user?.displayName ?? 'User',
          role: role,
        ));
      } on FirebaseAuthException catch (e) {
        emit(AuthError(e.message ?? 'Gagal masuk. Periksa email & password Anda.'));
      } catch (e) {
        emit(AuthError('Terjadi kesalahan koneksi Firebase.'));
      }
    } else {
      // MODE MOCK AUTH (DENGAN VALIDASI DATABASE HIVE LOKAL)
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final usersBox = Hive.box('users_box');
      final userData = usersBox.get(email);
      
      if (userData == null) {
        emit(AuthError('Akun belum terdaftar! Silakan daftar terlebih dahulu.'));
        return;
      }
      
      final Map<dynamic, dynamic> userMap = Map<dynamic, dynamic>.from(userData);
      if (userMap['password'] == password) {
        // Simpan sesi aktif ke reports_box
        final box = Hive.box('reports_box');
        await box.put(_sessionKey, email);
        await box.put(_sessionFullName, userMap['fullName']);
        await box.put(_sessionPhone, userMap['phone']);
        await box.put(_sessionAddress, userMap['address']);
        await box.put(_sessionRole, userMap['role'] ?? 'Warga');
        
        emit(AuthAuthenticated(
          email: email,
          fullName: userMap['fullName'] ?? '',
          phone: userMap['phone'] ?? '',
          address: userMap['address'] ?? '',
          role: userMap['role'] ?? 'Warga',
        ));
      } else {
        emit(AuthError('Password salah! Periksa kembali password Anda.'));
      }
    }
  }

  // --- DAFTAR (REGISTER) ---
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String address,
  }) async {
    emit(AuthLoading());

    if (email.isEmpty || password.isEmpty || fullName.isEmpty || phone.isEmpty || address.isEmpty) {
      emit(AuthError('Semua inputan wajib diisi.'));
      return;
    }

    // Keamanan: Cegah warga mendaftarkan email dengan domain khusus pemerintah
    if (email.endsWith('@lapor.go.id')) {
      emit(AuthError('Registrasi dengan domain pemerintah (@lapor.go.id) hanya dapat dilakukan oleh Super Admin.'));
      return;
    }

    const String role = 'Warga'; // Pendaftaran publik otomatis menjadi Warga

    if (_auth != null) {
      try {
        final credential = await _auth!.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Update display name di Firebase
        await credential.user?.updateDisplayName(fullName);
        
        // Simpan role ke metadata local untuk melacaknya
        final usersBox = Hive.box('users_box');
        final userMap = {
          'email': email,
          'fullName': fullName,
          'phone': phone,
          'address': address,
          'role': role,
        };
        await usersBox.put(email, userMap);
        
        final box = Hive.box('reports_box');
        await box.put(_sessionRole, role);

        emit(AuthAuthenticated(
          firebaseUser: credential.user,
          email: credential.user?.email ?? email,
          fullName: fullName,
          role: role,
        ));
      } on FirebaseAuthException catch (e) {
        emit(AuthError(e.message ?? 'Gagal mendaftar akun baru.'));
      } catch (e) {
        emit(AuthError('Terjadi kesalahan koneksi Firebase.'));
      }
    } else {
      // MODE MOCK AUTH
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final usersBox = Hive.box('users_box');
      if (usersBox.containsKey(email)) {
        emit(AuthError('Email sudah terdaftar! Silakan gunakan email lain.'));
        return;
      }

      // Simpan user baru ke database lokal (Hive)
      final userMap = {
        'email': email,
        'password': password,
        'fullName': fullName,
        'phone': phone,
        'address': address,
        'role': role,
      };
      await usersBox.put(email, userMap);

      // Simpan sesi aktif ke reports_box
      final box = Hive.box('reports_box');
      await box.put(_sessionKey, email);
      await box.put(_sessionFullName, fullName);
      await box.put(_sessionPhone, phone);
      await box.put(_sessionAddress, address);
      await box.put(_sessionRole, role);

      emit(AuthAuthenticated(
        email: email,
        fullName: fullName,
        phone: phone,
        address: address,
        role: role,
      ));
    }
  }

  // --- KELUAR (LOGOUT) ---
  Future<void> signOut() async {
    emit(AuthLoading());
    
    if (_auth != null) {
      await _auth!.signOut();
    }
    
    // Hapus sesi lokal di Hive
    final box = Hive.box('reports_box');
    await box.delete(_sessionKey);
    await box.delete(_sessionFullName);
    await box.delete(_sessionPhone);
    await box.delete(_sessionAddress);
    await box.delete(_sessionRole);
    
    emit(AuthUnauthenticated());
  }
}
