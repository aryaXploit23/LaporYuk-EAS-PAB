import 'dart:convert';

class ReportModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String imageUrl; // Bisa berupa file path lokal (jika offline) atau URL API remote
  final double latitude;
  final double longitude;
  final String status; // 'Menunggu', 'Diproses', 'Selesai'
  final DateTime createdAt;
  final bool isSynced; // Menyatakan apakah data sudah terkirim ke server API
  final String reporterEmail; // Email warga pelapor

  ReportModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    this.status = 'Menunggu',
    required this.createdAt,
    this.isSynced = true,
    this.reporterEmail = '',
  });

  ReportModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String? status,
    DateTime? createdAt,
    bool? isSynced,
    String? reporterEmail,
  }) {
    return ReportModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      reporterEmail: reporterEmail ?? this.reporterEmail,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0, // Bagus untuk database lokal
      'reporterEmail': reporterEmail,
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      status: map['status'] ?? 'Menunggu',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      isSynced: map['isSynced'] == 1 || map['isSynced'] == true,
      reporterEmail: map['reporterEmail'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory ReportModel.fromJson(String source) => ReportModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'ReportModel(id: $id, title: $title, category: $category, status: $status, isSynced: $isSynced, reporterEmail: $reporterEmail)';
  }
}
