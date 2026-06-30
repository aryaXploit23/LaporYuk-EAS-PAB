# 🏢 LaporYuk! - Aplikasi Pelaporan Fasilitas Publik (Smart City)

LaporYuk! adalah aplikasi mobile berbasis Flutter yang dirancang untuk membantu warga melaporkan kerusakan fasilitas publik secara real-time. Aplikasi ini mengusung arsitektur **Clean Architecture (BLoC/Cubit)**, mendukung **Offline-First Capabilities** dengan caching lokal, serta mengintegrasikan fitur perangkat keras seperti **Kamera (Image Picker)** dan **GPS/Maps (Geolocator & OpenStreetMap)**.

Aplikasi ini dibuat untuk memenuhi tugas **Evaluasi Akhir Semester (EAS) Pengembangan Aplikasi Bergerak / Kelas D**.

---

## 🛠️ Fitur Utama
1. **Autentikasi Pengguna**: Login, Registrasi, dan Logout menggunakan Firebase Authentication dengan mekanisme failover otomatis ke Local Mock Storage (Hive) jika dijalankan secara offline.
2. **Multi-Role User Dashboard**:
   - **Warga**: Dapat membuat laporan, melihat daftar laporan pribadi mereka, dan melihat peta sebaran laporan.
   - **Petugas**: Dapat melihat seluruh laporan warga, melakukan filter berdasarkan status, dan memperbarui status laporan (*Menunggu*, *Diproses*, *Selesai*).
3. **Penyimpanan Data & Cache Offline (Offline-First)**:
   - Data laporan yang diambil secara otomatis di-cache ke dalam **Hive Database**.
   - Ketika warga membuat laporan saat **Offline**, laporan disimpan ke dalam antrean draf lokal dan otomatis ditandai dengan ikon ☁️-off.
   - Fitur **Sync** satu ketukan untuk mengunggah seluruh draf laporan offline ke server saat koneksi internet kembali aktif.
4. **Integrasi Fitur Native Device**:
   - **Kamera / Galeri**: Untuk mengunggah bukti foto kerusakan langsung dari perangkat.
   - **GPS / Geolocator**: Mendeteksi koordinat latitude dan longitude lokasi kejadian secara otomatis.
   - **Peta Interaktif (OpenStreetMap)**: Visualisasi pin lokasi laporan secara riil menggunakan `flutter_map`.

---

## 📂 Struktur Arsitektur Kode
Proyek ini dirancang menggunakan arsitektur **Clean Architecture** yang terbagi dalam folder terstruktur:

```text
lib/
├── core/
│   └── constants/
│       └── api_endpoints.dart  # Konfigurasi endpoint REST API & Mock Mode
├── data/
│   ├── models/
│   │   └── report_model.dart   # Model data laporan (JSON & Map mapper)
│   ├── providers/
│   │   ├── local_storage_service.dart # Manajemen database Hive (caching & offline queue)
│   │   └── remote_api_client.dart     # HTTP Client menggunakan Dio (GET, POST, PUT, DELETE)
│   └── repositories/
│       └── report_repository.dart     # Single source of truth (sinkronisasi lokal & remote)
├── logic/
│   ├── auth/
│   │   ├── auth_cubit.dart     # Manajemen state autentikasi (Firebase/Mock)
│   │   └── auth_state.dart
│   └── reports/
│       ├── reports_cubit.dart  # Manajemen state daftar & aksi laporan
│       └── reports_state.dart
└── presentation/
    └── pages/
        ├── auth_page.dart           # UI Halaman Login & Register
        ├── dashboard_page.dart      # UI Halaman Utama (Feed & Peta Sebaran)
        ├── create_report_page.dart  # UI Form Tambah Laporan (Kamera & GPS)
        └── report_detail_page.dart  # UI Detail Laporan & Update Status Petugas
```

---

## 🚀 Panduan Instalasi & Menjalankan Aplikasi

### Prasyarat
- [Flutter SDK](https://docs.flutter.dev/get-started/install) versi 3.12.0 atau lebih baru.
- Android Studio / VS Code dengan plugin Flutter & Dart.
- Perangkat Android (Fisik) atau Emulator.

### Langkah-Langkah Running
1. Clone repositori ini:
   ```bash
   git clone <URL_REPOSITORI_ANDA>
   cd flutter_uas
   ```
2. Jalankan perintah `pub get` untuk mengunduh dependensi:
   ```bash
   flutter pub get
   ```
3. Hubungkan perangkat Android/Emulator Anda.
4. Jalankan aplikasi dalam mode debug:
   ```bash
   flutter run
   ```
5. *(Opsional)* Untuk membuat file instalasi APK rilis:
   ```bash
   flutter build apk --release
   ```
   File APK hasil build akan berada di `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📝 Konfigurasi API Client (Online/Offline Mode)
Untuk kenyamanan pengujian di depan dosen, aplikasi dilengkapi dengan parameter toggle `useLocalMock` di [api_endpoints.dart](file:///c:/Users/arya/OneDrive/Dokumen/semester6/PRAKTIKUM%20PAB/flutter_uas/lib/core/constants/api_endpoints.dart):
- `useLocalMock = true` (Default): Menggunakan database lokal Hive sepenuhnya untuk mensimulasikan server API, sehingga demo **dijamin 100% lancar bebas error jaringan**.
- `useLocalMock = false`: Menghubungkan aplikasi langsung ke REST API server (Dio client) ke endpoint yang disediakan.

---

## 📸 Antarmuka Aplikasi (Screenshots)

Berikut adalah beberapa tampilan penting dalam aplikasi **LaporYuk!**:

### 1. Halaman Autentikasi (Login & Register)
*Tampilan form masuk dan pendaftaran yang konsisten menggunakan Dark Mode modern beraksen Cyan.*

### 2. Dashboard Warga (Feed Laporan & Peta Sebaran)
*Menampilkan daftar laporan pribadi warga dengan penanda status (Menunggu, Diproses, Selesai) serta Peta Sebaran interaktif menggunakan GPS.*

### 3. Simulasi Laporan Offline (Draft & Sync)
*Ketika warga melaporkan saat offline, laporan masuk ke draf lokal dengan label awan tercoret. Tombol Sync di bagian kanan atas digunakan untuk mengunggah draf ketika jaringan kembali pulih.*

### 4. Dashboard Petugas (Filter Status & Update Progres)
*Dashboard khusus petugas yang memiliki filter status laporan dan tombol simulasi untuk memperbarui progres laporan warga secara langsung.*

---
*Dibuat oleh Tim Pengembang Aplikasi Bergerak - Universitas 17 Agustus 1945 Surabaya.*
