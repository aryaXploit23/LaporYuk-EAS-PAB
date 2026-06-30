import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository.dart';
import 'reports_state.dart';

class ReportsCubit extends Cubit<ReportsState> {
  final ReportRepository repository;

  ReportsCubit({required this.repository}) : super(ReportsInitial());

  // --- AMBIL SEMUA LAPORAN ---
  Future<void> fetchReports() async {
    emit(ReportsLoading());
    try {
      final reports = await repository.getReports();
      emit(ReportsLoaded(reports));
    } catch (e) {
      emit(ReportsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // --- KIRIM LAPORAN BARU ---
  Future<void> createReport({
    required String title,
    required String description,
    required String category,
    required String imageUrl,
    required double latitude,
    required double longitude,
    required String reporterEmail,
  }) async {
    emit(ReportsLoading());
    final newReport = ReportModel(
      id: '', // Di-generate di repository/server
      title: title,
      description: description,
      category: category,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
      reporterEmail: reporterEmail,
    );

    try {
      await repository.createReport(newReport);
      // Sukses kirim ke server API online, refresh data
      final reports = await repository.getReports();
      emit(ReportsLoaded(reports, message: 'Laporan berhasil terkirim ke server!'));
    } on SocketException catch (e) {
      // Ditangani sebagai offline draf oleh repository
      final reports = await repository.getReports();
      emit(ReportsLoaded(reports, message: e.message));
    } catch (e) {
      emit(ReportsError('Gagal membuat laporan: ${e.toString()}'));
    }
  }

  // --- HAPUS LAPORAN ---
  Future<void> deleteReport(String id) async {
    emit(ReportsLoading());
    try {
      await repository.deleteReport(id);
      final reports = await repository.getReports();
      emit(ReportsLoaded(reports, message: 'Laporan berhasil dihapus!'));
    } catch (e) {
      emit(ReportsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // --- SINKRONISASI OFFLINE DRAFT ---
  Future<void> syncOfflineReports() async {
    // Jalankan sync
    try {
      final syncedCount = await repository.syncOfflineReports();
      if (syncedCount > 0) {
        final reports = await repository.getReports();
        emit(ReportsLoaded(reports, message: 'Berhasil mensinkronkan $syncedCount laporan offline!'));
      }
    } catch (_) {
      // Hiraukan error sync jika jaringan masih bermasalah
    }
  }
}
