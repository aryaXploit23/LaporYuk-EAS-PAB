import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/report_model.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/reports/reports_cubit.dart';
import '../../logic/reports/reports_state.dart';
import 'auth_page.dart';
import 'create_report_page.dart';
import 'report_detail_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MapController _mapController = MapController();
  String _selectedStatusFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Trigger fetch reports on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsCubit>().fetchReports();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper untuk menentukan warna status badge
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

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final email = authState is AuthAuthenticated ? authState.email : 'User';
    final fullName = authState is AuthAuthenticated ? authState.fullName : 'User';
    final phone = authState is AuthAuthenticated ? authState.phone : '-';
    final address = authState is AuthAuthenticated ? authState.address : '-';
    final role = authState is AuthAuthenticated ? authState.role : 'Warga';

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B2D36),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Halo, ${fullName.split(' ').first}!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.cyanAccent),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: role == 'Petugas' ? Colors.redAccent : Colors.teal,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const Text(
              'LaporYuk! Smart City',
              style: TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Tombol Info Profil User
          IconButton(
            icon: const Icon(Icons.person_pin_rounded, color: Colors.cyanAccent),
            tooltip: 'Profil Saya',
            onPressed: () {
              _showProfileDialog(context, email, fullName, phone, address);
            },
          ),
          // Tombol Sinkronisasi Offline Draft
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Colors.cyanAccent),
            tooltip: 'Sinkronisasi Laporan Offline',
            onPressed: () {
              context.read<ReportsCubit>().syncOfflineReports();
            },
          ),
          // Tombol Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () {
              context.read<AuthCubit>().signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded), text: 'Feed Laporan'),
            Tab(icon: Icon(Icons.map_rounded), text: 'Peta Sebaran'),
          ],
        ),
      ),
      body: BlocConsumer<ReportsCubit, ReportsState>(
        listener: (context, state) {
          if (state is ReportsLoaded && state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message!),
                backgroundColor: state.message!.contains('gagal') || state.message!.contains('offline')
                    ? Colors.orangeAccent
                    : Colors.teal,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ReportsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            );
          }

          if (state is ReportsError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
                      onPressed: () => context.read<ReportsCubit>().fetchReports(),
                      child: const Text('Coba Lagi', style: TextStyle(color: Color(0xFF0F2027))),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is ReportsLoaded) {
            final rawReports = state.reports;
            final baseReports = role == 'Warga'
                ? rawReports.where((r) => r.reporterEmail == email).toList()
                : rawReports;
            final unsyncedCount = baseReports.where((r) => !r.isSynced).length;

            // Apply status filter for Petugas
            final reports = role == 'Petugas' && _selectedStatusFilter != 'Semua'
                ? baseReports.where((r) => r.status == _selectedStatusFilter).toList()
                : baseReports;

            Widget buildTabBarView() {
              return TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: FEED LIST LAPORAN
                  RefreshIndicator(
                    color: Colors.cyanAccent,
                    onRefresh: () => context.read<ReportsCubit>().fetchReports(),
                    child: Column(
                      children: [
                        // Banner peringatan laporan offline belum terkirim
                        if (unsyncedCount > 0)
                          Container(
                            width: double.infinity,
                            color: Colors.orangeAccent.withOpacity(0.9),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.cloud_off_rounded, color: Color(0xFF0F2027)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Terdapat $unsyncedCount draf laporan disimpan di HP. Klik ikon sinkronisasi (sync) di atas saat Anda online.',
                                    style: const TextStyle(
                                      color: Color(0xFF0F2027),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        Expanded(
                          child: reports.isEmpty
                              ? Center(
                                  child: Text(
                                    _selectedStatusFilter == 'Semua'
                                        ? 'Belum ada laporan masuk.\nKlik tombol (+) di bawah untuk membuat laporan!'
                                        : 'Tidak ada laporan dengan status "$_selectedStatusFilter".',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: reports.length,
                                  itemBuilder: (context, index) {
                                    final report = reports[index];
                                    return _buildReportCard(context, report);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  // TAB 2: PETA SEBARAN (OPENSTREETMAP)
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: reports.isNotEmpty
                          ? LatLng(reports.first.latitude, reports.first.longitude)
                          : const LatLng(-7.2985, 112.7684), // Default Kampus UNTAG Surabaya
                      initialZoom: 14.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.flutter_uas',
                      ),
                      MarkerLayer(
                        markers: reports.map((report) {
                          return Marker(
                            point: LatLng(report.latitude, report.longitude),
                            width: 80,
                            height: 80,
                            child: GestureDetector(
                              onTap: () {
                                _showMapMarkerDialog(context, report);
                              },
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(report.status),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white, width: 1),
                                    ),
                                    child: Text(
                                      report.category,
                                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.location_pin,
                                    color: Colors.redAccent,
                                    size: 32,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              );
            }

            if (role == 'Petugas') {
              return Column(
                children: [
                  _buildFilterBar(),
                  Expanded(child: buildTabBarView()),
                ],
              );
            }

            return buildTabBarView();
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: role == 'Petugas'
          ? null
          : FloatingActionButton(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: const Color(0xFF0F2027),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateReportPage()),
                );
              },
              child: const Icon(Icons.add_a_photo_rounded),
            ),
    );
  }

  // Widget Card Item Laporan
  Widget _buildReportCard(BuildContext context, ReportModel report) {
    return Card(
      color: const Color(0xFF1B2D36),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final authState = context.read<AuthCubit>().state;
          final role = authState is AuthAuthenticated ? authState.role : 'Warga';
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ReportDetailPage(report: report, role: role)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Preview
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: report.imageUrl.startsWith('http')
                      ? Image.network(
                          report.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white10,
                            child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
                          ),
                        )
                      : report.imageUrl.startsWith('data:image')
                          ? Image.memory(
                              base64Decode(report.imageUrl.split(',').last),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.white10,
                                child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
                              ),
                            )
                          : kIsWeb
                              ? Image.network(
                                  report.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white10,
                                    child: const Icon(Icons.image_outlined, color: Colors.white38),
                                  ),
                                )
                              : Image.file(
                                  File(report.imageUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white10,
                                    child: const Icon(Icons.image_outlined, color: Colors.white38),
                                  ),
                                ),
                ),
              ),
              const SizedBox(width: 16),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Status & Sync Tag
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(report.status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _getStatusColor(report.status), width: 1),
                          ),
                          child: Text(
                            report.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(report.status),
                            ),
                          ),
                        ),
                        if (!report.isSynced)
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 16,
                            color: Colors.orangeAccent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      report.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Description snippet
                    Text(
                      report.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Date & Category
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          report.category,
                          style: const TextStyle(fontSize: 10, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${report.createdAt.day}/${report.createdAt.month} ${report.createdAt.hour.toString().padLeft(2, '0')}:${report.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dialog pop-up marker peta
  void _showMapMarkerDialog(BuildContext context, ReportModel report) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2D36),
          title: Text(report.title, style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kategori: ${report.category}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 13)),
              const SizedBox(height: 8),
              Text(report.description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(report.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _getStatusColor(report.status)),
                    ),
                    child: Text(
                      report.status,
                      style: TextStyle(color: _getStatusColor(report.status), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
              onPressed: () {
                final authState = context.read<AuthCubit>().state;
                final role = authState is AuthAuthenticated ? authState.role : 'Warga';
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReportDetailPage(report: report, role: role)),
                );
              },
              child: const Text('Detail', style: TextStyle(color: Color(0xFF0F2027))),
            ),
          ],
        );
      },
    );
  }

  // Dialog Detail Profil Warga
  void _showProfileDialog(BuildContext context, String email, String fullName, String phone, String address) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2D36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_pin_rounded, color: Colors.cyanAccent, size: 28),
              SizedBox(width: 8),
              Text('Profil Pelapor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileItem('Nama Lengkap:', fullName),
              const SizedBox(height: 12),
              _buildProfileItem('Email:', email),
              const SizedBox(height: 12),
              _buildProfileItem('Nomor HP:', phone),
              const SizedBox(height: 12),
              _buildProfileItem('Alamat:', address),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: const Color(0xFF0F2027),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Baris filter status khusus Petugas
  Widget _buildFilterBar() {
    final statuses = ['Semua', 'Menunggu', 'Diproses', 'Selesai'];
    return Container(
      color: const Color(0xFF1B2D36),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded, color: Colors.cyanAccent, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Filter:',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statuses.map((status) {
                  final isSelected = _selectedStatusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedStatusFilter = status;
                          });
                        }
                      },
                      labelStyle: TextStyle(
                        color: isSelected ? const Color(0xFF0F2027) : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      selectedColor: Colors.cyanAccent,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? Colors.cyanAccent : Colors.white.withOpacity(0.12),
                          width: 1,
                        ),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
