import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/report_model.dart';
import '../../logic/reports/reports_cubit.dart';

class ReportDetailPage extends StatelessWidget {
  final ReportModel report;
  final String role;

  const ReportDetailPage({super.key, required this.report, required this.role});

  // Helper warna status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Diproses':
        return Colors.blueAccent;
      case 'Selesai':
        return Colors.greenAccent;
      case 'Menunggu':
      default:
        return Colors.amberAccent;
    }
  }

  // --- DIALOG KONFIRMASI HAPUS ---
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2D36),
          title: const Text('Hapus Laporan?', style: TextStyle(color: Colors.white)),
          content: const Text('Apakah Anda yakin ingin menghapus laporan ini? Tindakan ini tidak bisa dibatalkan.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.of(ctx).pop(); // Tutup dialog
                context.read<ReportsCubit>().deleteReport(report.id);
                Navigator.of(context).pop(); // Kembali ke Dashboard
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- SIMULASI UPDATE STATUS (PUT) ---
  void _updateStatus(BuildContext context) {
    String nextStatus = 'Diproses';
    if (report.status == 'Diproses') {
      nextStatus = 'Selesai';
    } else if (report.status == 'Selesai') {
      nextStatus = 'Menunggu';
    }

    // Melakukan update
    context.read<ReportsCubit>().repository.remoteApiClient.updateReportStatus(report.id, nextStatus).then((_) {
      context.read<ReportsCubit>().fetchReports(); // Refresh data dashboard
      Navigator.of(context).pop(); // Kembali ke Dashboard
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status laporan berhasil diperbarui menjadi "$nextStatus"!'),
          backgroundColor: Colors.teal,
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(report.status);

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B2D36),
        title: const Text('Detail Laporan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        actions: [
          // Tombol Hapus Laporan (DELETE) hanya untuk Warga pencipta draf
          if (role == 'Warga')
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              tooltip: 'Hapus Laporan',
              onPressed: () => _confirmDelete(context),
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Bukti Kerusakan Utama
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 250,
                  child: report.imageUrl.startsWith('http')
                      ? Image.network(
                          report.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white10,
                            child: const Icon(Icons.broken_image_outlined, size: 64, color: Colors.white38),
                          ),
                        )
                      : report.imageUrl.startsWith('data:image')
                          ? Image.memory(
                              base64Decode(report.imageUrl.split(',').last),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.white10,
                                child: const Icon(Icons.broken_image_outlined, size: 64, color: Colors.white38),
                              ),
                            )
                          : kIsWeb
                              ? Image.network(
                                  report.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white10,
                                    child: const Icon(Icons.image_outlined, size: 64, color: Colors.white38),
                                  ),
                                )
                              : Image.file(
                                  File(report.imageUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white10,
                                    child: const Icon(Icons.image_outlined, size: 64, color: Colors.white38),
                                  ),
                                ),
                ),
                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
                // Category Tag
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      report.category,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2027), fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Judul & Badge Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          report.title,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor, width: 1.5),
                        ),
                        child: Text(
                          report.status,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tanggal & Status Sync
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: Colors.white38),
                      const SizedBox(width: 6),
                      Text(
                        'Dilaporkan pada: ${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year} ${report.createdAt.hour.toString().padLeft(2, '0')}:${report.createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      const Spacer(),
                      if (!report.isSynced)
                        const Row(
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 14, color: Colors.orangeAccent),
                            SizedBox(width: 4),
                            Text('Draf Offline', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        )
                      else
                        const Row(
                          children: [
                            Icon(Icons.cloud_done_rounded, size: 14, color: Colors.tealAccent),
                            SizedBox(width: 4),
                            Text('Tersinkron', style: TextStyle(color: Colors.tealAccent, fontSize: 11)),
                          ],
                        ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 32),

                  // Deskripsi
                  const Text(
                    'Deskripsi Kejadian:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.description,
                    style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
                  ),
                  const Divider(color: Colors.white12, height: 32),

                  // Informasi Lokasi & Peta Mini
                  const Text(
                    'Lokasi Kerusakan:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Koordinat: ${report.latitude.toStringAsFixed(6)}, ${report.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 13, color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  
                  // Peta Mini
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(report.latitude, report.longitude),
                          initialZoom: 15.0,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none), // Non-interactive peta mini
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.flutter_uas',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(report.latitude, report.longitude),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.redAccent,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Tombol Simulasi Aksi Petugas (Mengubah Status) hanya untuk Petugas
                  if (role == 'Petugas')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B2D36),
                          foregroundColor: Colors.cyanAccent,
                          side: const BorderSide(color: Colors.cyanAccent),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _updateStatus(context),
                        icon: const Icon(Icons.settings_backup_restore_rounded),
                        label: Text(
                          report.status == 'Selesai'
                              ? 'Simulasi: Reset ke Menunggu'
                              : (report.status == 'Diproses' ? 'Simulasi: Tandai Selesai' : 'Simulasi: Tandai Diproses'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
