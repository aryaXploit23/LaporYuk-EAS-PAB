import 'dart:io';
import 'package:dio/dio.dart';
import '../models/report_model.dart';
import '../providers/local_storage_service.dart';
import '../providers/remote_api_client.dart';

class ReportRepository {
  final RemoteApiClient remoteApiClient;
  final LocalStorageService localStorageService;

  ReportRepository({
    required this.remoteApiClient,
    required this.localStorageService,
  });

  // --- AMBIL SEMUA LAPORAN (Offline-First Feed) ---
  Future<List<ReportModel>> getReports() async {
    try {
      // 1. Coba ambil data terbaru dari server API
      final remoteReports = await remoteApiClient.getReports();
      
      // 2. Jika sukses, simpan/perbarui cache lokal
      await localStorageService.cacheReports(remoteReports);
      
      // Ambil gabungan data cache + antrian offline (yang belum terkirim)
      return _mergeReports(remoteReports);
    } catch (e) {
      // 3. Jika gagal (koneksi offline/error), ambil dari cache lokal
      final cachedReports = localStorageService.getCachedReports();
      if (cachedReports.isEmpty) {
        // Jika cache kosong dan offline, lempar error asli
        throw Exception('Koneksi internet tidak tersedia dan tidak ada cache lokal.');
      }
      return _mergeReports(cachedReports);
    }
  }

  // --- BUAT LAPORAN BARU ---
  Future<ReportModel> createReport(ReportModel report) async {
    try {
      // 1. Coba kirim ke server API langsung
      final createdReport = await remoteApiClient.createReport(report);
      return createdReport;
    } catch (e) {
      // 2. Jika offline/gagal kirim, masukkan ke antrian offline (Local Storage)
      final offlineReport = report.copyWith(
        id: report.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : report.id,
        isSynced: false,
      );
      await localStorageService.addToOfflineQueue(offlineReport);
      
      // Tambahkan juga ke cache agar langsung tampil di list aplikasi
      final cached = localStorageService.getCachedReports();
      cached.insert(0, offlineReport);
      await localStorageService.cacheReports(cached);
      
      // Lempar exception offline khusus agar UI bisa menampilkan feedback
      throw SocketException('Laporan disimpan di draf lokal karena Anda sedang offline.');
    }
  }

  // --- HAPUS LAPORAN ---
  Future<void> deleteReport(String id) async {
    try {
      // Hapus dari server
      await remoteApiClient.deleteReport(id);
      
      // Hapus dari cache lokal jika ada
      final cached = localStorageService.getCachedReports();
      cached.removeWhere((r) => r.id == id);
      await localStorageService.cacheReports(cached);
      
      // Hapus dari antrian offline jika tersimpan di sana
      await localStorageService.removeFromOfflineQueue(id);
    } catch (e) {
      // Jika offline dan laporan merupakan draf lokal, izinkan menghapusnya langsung
      final offlineQueue = localStorageService.getOfflineQueue();
      final isOfflineDraft = offlineQueue.any((r) => r.id == id);
      
      if (isOfflineDraft) {
        await localStorageService.removeFromOfflineQueue(id);
        final cached = localStorageService.getCachedReports();
        cached.removeWhere((r) => r.id == id);
        await localStorageService.cacheReports(cached);
      } else {
        throw Exception('Gagal menghapus laporan dari server. Periksa koneksi internet Anda.');
      }
    }
  }

  // --- SINKRONISASI DATA OFFLINE KE SERVER ---
  Future<int> syncOfflineReports() async {
    final offlineQueue = localStorageService.getOfflineQueue();
    if (offlineQueue.isEmpty) return 0;

    int syncedCount = 0;
    for (var report in offlineQueue) {
      try {
        // Kirim ke server
        await remoteApiClient.createReport(report);
        // Hapus dari antrian offline setelah berhasil
        await localStorageService.removeFromOfflineQueue(report.id);
        syncedCount++;
      } catch (e) {
        // Hentikan proses sinkronisasi jika terjadi error lagi
        break;
      }
    }

    // Refresh cache local jika ada data yang berhasil disinkronkan
    if (syncedCount > 0) {
      try {
        final remoteReports = await remoteApiClient.getReports();
        await localStorageService.cacheReports(remoteReports);
      } catch (_) {}
    }

    return syncedCount;
  }

  // Helper untuk menggabungkan data remote/cache dengan antrian offline
  List<ReportModel> _mergeReports(List<ReportModel> baseReports) {
    final offlineQueue = localStorageService.getOfflineQueue();
    if (offlineQueue.isEmpty) return baseReports;

    final List<ReportModel> merged = List.from(baseReports);
    // Hapus laporan di base yang memiliki ID sama dengan antrian offline untuk menghindari duplikasi
    for (var offlineReport in offlineQueue) {
      merged.removeWhere((r) => r.id == offlineReport.id);
      merged.insert(0, offlineReport); // Tampilkan draf offline di paling atas
    }
    
    // Sort ulang berdasarkan tanggal terbaru
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }
}
