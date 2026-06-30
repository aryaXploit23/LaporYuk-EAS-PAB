import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../logic/reports/reports_cubit.dart';
import '../../logic/auth/auth_cubit.dart';

class CreateReportPage extends StatefulWidget {
  const CreateReportPage({super.key});

  @override
  State<CreateReportPage> createState() => _CreateReportPageState();
}

class _CreateReportPageState extends State<CreateReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  String _selectedCategory = 'Jalan Rusak';
  String? _imagePath;
  
  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;

  final List<String> _categories = [
    'Jalan Rusak',
    'Lampu Mati',
    'Sampah Menumpuk',
    'Lainnya'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // --- AMBIL FOTO ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 40, // Kompres kualitas gambar agak rendah agar string Base64 tidak terlalu besar
      );
      
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _imagePath = base64String;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil gambar')),
      );
    }
  }

  // --- GET GPS LOCATION ---
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // 1. Cek apakah layanan GPS aktif
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Layanan GPS tidak aktif. Silakan aktifkan GPS Anda.';
      }

      // 2. Cek/Request Izin Lokasi
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Izin akses lokasi ditolak oleh pengguna.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak permanen. Silakan ubah izin lokasi di Pengaturan HP.';
      }

      // 3. Dapatkan koordinat saat ini
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi GPS berhasil diperoleh!'), backgroundColor: Colors.teal),
      );
    } catch (e) {
      // Fallback ke koordinat default (UNTAG Surabaya) jika gagal agar aplikasi tidak mandek
      setState(() {
        _latitude = -7.2985;
        _longitude = 112.7684;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e\nLokasi otomatis diset ke Kampus UNTAG (Surabaya).'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  // --- SUBMIT REPORT ---
  void _submitReport() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus menyertakan foto bukti kerusakan!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon tekan tombol Dapatkan Lokasi GPS terlebih dahulu!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final authState = context.read<AuthCubit>().state;
    final reporterEmail = authState is AuthAuthenticated ? authState.email : 'anon@gmail.com';

    context.read<ReportsCubit>().createReport(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      imageUrl: _imagePath!,
      latitude: _latitude!,
      longitude: _longitude!,
      reporterEmail: reporterEmail,
    );

    Navigator.of(context).pop(); // Kembali ke dashboard
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B2D36),
        title: const Text('Buat Laporan Baru', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Judul Laporan
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Judul Laporan', Icons.title_rounded),
                validator: (value) => value == null || value.trim().isEmpty ? 'Judul tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),

              // Deskripsi Laporan
              TextFormField(
                controller: _descController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Deskripsi Masalah / Lokasi Detail', Icons.description_rounded),
                validator: (value) => value == null || value.trim().isEmpty ? 'Deskripsi tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),

              // Kategori Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                style: const TextStyle(color: Colors.white),
                dropdownColor: const Color(0xFF1B2D36),
                decoration: _buildInputDecoration('Kategori Fasilitas', Icons.category_rounded),
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Bagian Ambil Foto
              const Text(
                'Bukti Foto Kerusakan',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: _imagePath != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                          child: _imagePath!.startsWith('data:image')
                              ? Image.memory(
                                  base64Decode(_imagePath!.split(',').last),
                                  fit: BoxFit.cover,
                                )
                              : kIsWeb
                                  ? Image.network(
                                      _imagePath!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_imagePath!),
                                      fit: BoxFit.cover,
                                    ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.redAccent,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _imagePath = null;
                                  });
                                },
                              ),
                            ),
                          )
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildImagePickButton(
                            icon: Icons.camera_alt_rounded,
                            label: 'Kamera',
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                          _buildImagePickButton(
                            icon: Icons.photo_library_rounded,
                            label: 'Galeri',
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // Bagian GPS Lokasi
              const Text(
                'Lokasi Kejadian (GPS)',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  children: [
                    if (_latitude != null && _longitude != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Lat: ${_latitude!.toStringAsFixed(5)}, Long: ${_longitude!.toStringAsFixed(5)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'Koordinat belum diperoleh.',
                        style: TextStyle(color: Colors.white38),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isGettingLocation ? null : _getCurrentLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.withOpacity(0.1),
                        foregroundColor: Colors.cyanAccent,
                        side: const BorderSide(color: Colors.cyanAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      ),
                      icon: _isGettingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                            )
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: Text(_isGettingLocation ? 'Mendeteksi GPS...' : 'Dapatkan Lokasi GPS'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: const Color(0xFF0F2027),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: const Text(
                  'KIRIM LAPORAN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Custom Input Decoration helper
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.cyanAccent),
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  // Tombol ambil foto helper
  Widget _buildImagePickButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 40),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
