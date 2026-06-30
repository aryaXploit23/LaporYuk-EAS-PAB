import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/api_endpoints.dart';
import '../models/report_model.dart';

class RemoteApiClient {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  // Data mock lokal di memori agar aplikasi bisa didemo secara lancar tanpa internet/server
  static final List<ReportModel> _mockReports = [
    ReportModel(
      id: '1',
      title: 'Jalan Berlubang Parah',
      description: 'Ada lubang besar di tengah jalan raya dekat gerbang kampus UNTAG. Sangat membahayakan pengendara motor di malam hari.',
      category: 'Jalan Rusak',
      imageUrl: 'https://images.unsplash.com/photo-1515162305285-0293e4767cc2?q=80&w=500',
      latitude: -7.2985,
      longitude: 112.7684,
      status: 'Menunggu',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      reporterEmail: 'warga_lain@gmail.com',
    ),
    ReportModel(
      id: '2',
      title: 'Lampu Penerangan Jalan Mati',
      description: 'Lampu jalan PJU di sepanjang Jalan Semolowaru No 45 mati total, suasana jalanan menjadi gelap gulita saat malam.',
      category: 'Lampu Mati',
      imageUrl: 'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?q=80&w=500',
      latitude: -7.2990,
      longitude: 112.7675,
      status: 'Diproses',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      reporterEmail: 'warga_lain@gmail.com',
    ),
    ReportModel(
      id: '3',
      title: 'Tumpukan Sampah Liar',
      description: 'Masyarakat membuang sampah sembarangan di pinggir trotoar jalan. Menimbulkan bau busuk menyengat dan merusak pemandangan.',
      category: 'Sampah Menumpuk',
      imageUrl: 'https://images.unsplash.com/photo-1611284446314-60a58ac0deb9?q=80&w=500',
      latitude: -7.3005,
      longitude: 112.7690,
      status: 'Selesai',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      reporterEmail: 'warga_lain@gmail.com',
    ),
  ];

  // --- API OPERATIONS ---

  // 1. GET ALL REPORTS
  Future<List<ReportModel>> getReports() async {
    if (ApiEndpoints.useLocalMock) {
      // Simulasi delay jaringan 1.5 detik
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final box = Hive.box('mock_reports_box');
      if (box.isEmpty) {
        // Isi dengan data awal jika database mock kosong
        for (var report in _mockReports) {
          await box.put(report.id, report.toMap());
        }
      }
      
      return box.values
          .map((item) => ReportModel.fromMap(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    try {
      final response = await _dio.get(ApiEndpoints.reports);
      if (response.statusCode == 200) {
        final List data = response.data;
        return data.map((item) => ReportModel.fromMap(item)).toList();
      }
      throw DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.reports),
        response: response,
      );
    } catch (e) {
      rethrow;
    }
  }

  // 2. CREATE REPORT (POST)
  Future<ReportModel> createReport(ReportModel report) async {
    if (ApiEndpoints.useLocalMock) {
      await Future.delayed(const Duration(milliseconds: 2000));
      final newReport = report.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        status: 'Menunggu',
        isSynced: true,
      );
      
      final box = Hive.box('mock_reports_box');
      await box.put(newReport.id, newReport.toMap());
      return newReport;
    }

    try {
      // Mengirim dengan FormData jika menyertakan berkas gambar (multi-part)
      final mapData = report.toMap();
      
      // Jika imageUrl berupa path file lokal, kita simulasikan upload
      // Catatan: Di backend sesungguhnya, gunakan MultipartFile.fromFile(report.imageUrl)
      final response = await _dio.post(
        ApiEndpoints.reports,
        data: mapData,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ReportModel.fromMap(response.data);
      }
      throw DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.reports),
        response: response,
      );
    } catch (e) {
      rethrow;
    }
  }

  // 3. UPDATE REPORT STATUS (PUT)
  Future<ReportModel> updateReportStatus(String id, String newStatus) async {
    if (ApiEndpoints.useLocalMock) {
      await Future.delayed(const Duration(milliseconds: 1000));
      final box = Hive.box('mock_reports_box');
      final data = box.get(id);
      if (data != null) {
        final report = ReportModel.fromMap(Map<String, dynamic>.from(data));
        final updated = report.copyWith(status: newStatus);
        await box.put(id, updated.toMap());
        return updated;
      }
      throw Exception('Report not found');
    }

    try {
      final response = await _dio.put(
        '${ApiEndpoints.reports}/$id',
        data: {'status': newStatus},
      );
      if (response.statusCode == 200) {
        return ReportModel.fromMap(response.data);
      }
      throw DioException(
        requestOptions: RequestOptions(path: '${ApiEndpoints.reports}/$id'),
        response: response,
      );
    } catch (e) {
      rethrow;
    }
  }

  // 4. DELETE REPORT (DELETE)
  Future<void> deleteReport(String id) async {
    if (ApiEndpoints.useLocalMock) {
      await Future.delayed(const Duration(milliseconds: 1000));
      final box = Hive.box('mock_reports_box');
      await box.delete(id);
      return;
    }

    try {
      final response = await _dio.delete('${ApiEndpoints.reports}/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }
      throw DioException(
        requestOptions: RequestOptions(path: '${ApiEndpoints.reports}/$id'),
        response: response,
      );
    } catch (e) {
      rethrow;
    }
  }
}
