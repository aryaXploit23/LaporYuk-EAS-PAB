import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/constants/api_endpoints.dart';
import 'data/providers/local_storage_service.dart';
import 'data/providers/remote_api_client.dart';
import 'data/repositories/report_repository.dart';
import 'logic/auth/auth_cubit.dart';
import 'logic/auth/auth_state.dart';
import 'logic/reports/reports_cubit.dart';
import 'presentation/pages/auth_page.dart';
import 'presentation/pages/dashboard_page.dart';

void main() async {
  // Pastikan binding Flutter diinisialisasi sebelum pengerjaan async
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi Database Lokal Hive
  final localStorage = LocalStorageService();
  await localStorage.init();

  // 2. Inisialisasi Firebase (dengan try-catch agar toleran jika project Firebase belum di-link)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase berhasil diinisialisasi.");
  } catch (e) {
    debugPrint("Firebase tidak terdeteksi atau konfigurasi belum di-setup. Aplikasi berjalan dalam Mode Mock.");
  }

  // 3. Inisialisasi API client & Repository
  final remoteApiClient = RemoteApiClient();
  final repository = ReportRepository(
    remoteApiClient: remoteApiClient,
    localStorageService: localStorage,
  );

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: repository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthCubit()..checkCurrentUser(),
          ),
          BlocProvider(
            create: (context) => ReportsCubit(repository: repository),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LaporYuk!',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F2027),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
          primary: Colors.cyanAccent,
          secondary: Colors.cyan,
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return const DashboardPage();
          }
          return const AuthPage();
        },
      ),
    );
  }
}
