import 'package:hive_flutter/hive_flutter.dart';
import '../models/report_model.dart';

class LocalStorageService {
  static const String _reportsBoxName = 'reports_box';
  static const String _offlineQueueBoxName = 'offline_queue_box';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_reportsBoxName);
    await Hive.openBox(_offlineQueueBoxName);
    await Hive.openBox('users_box');
    await Hive.openBox('mock_reports_box');
  }

  // --- MANAJEMEN CACHE LAPORAN (Dashboard Feed) ---

  // Simpan list laporan ke cache
  Future<void> cacheReports(List<ReportModel> reports) async {
    final box = Hive.box(_reportsBoxName);
    await box.clear();
    for (var report in reports) {
      await box.put(report.id, report.toMap());
    }
  }

  // Ambil list laporan dari cache
  List<ReportModel> getCachedReports() {
    final box = Hive.box(_reportsBoxName);
    return box.values
        .map((item) => ReportModel.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by date desc
  }

  // --- MANAJEMEN ANTRIAN OFFLINE (Draft yang belum sinkron) ---

  // Simpan laporan ke antrian offline
  Future<void> addToOfflineQueue(ReportModel report) async {
    final box = Hive.box(_offlineQueueBoxName);
    // Tandai report sebagai belum tersinkronisasi
    final unsyncedReport = report.copyWith(isSynced: false);
    await box.put(unsyncedReport.id, unsyncedReport.toMap());
  }

  // Ambil semua laporan yang ada di antrian offline
  List<ReportModel> getOfflineQueue() {
    final box = Hive.box(_offlineQueueBoxName);
    return box.values
        .map((item) => ReportModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // Hapus laporan dari antrian offline setelah sukses di-sync ke server
  Future<void> removeFromOfflineQueue(String id) async {
    final box = Hive.box(_offlineQueueBoxName);
    await box.delete(id);
  }

  // Bersihkan semua data cache & antrian
  Future<void> clearAll() async {
    await Hive.box(_reportsBoxName).clear();
    await Hive.box(_offlineQueueBoxName).clear();
  }
}
