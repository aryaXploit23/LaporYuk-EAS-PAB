# LAPORAN PENGERJAAN EVALUASI AKHIR SEMESTER (EAS)
## MATA KULIAH: PENGEMBANGAN APLIKASI BERGERAK (KELAS D)

---

### **COVER LAPORAN**
* **Nama**: [Isi Nama Anda]
* **NBI**: [Isi NBI/NIM Anda]
* **Kelas**: PENGEMBANGAN APLIKASI BERGERAK / D
* **Dosen Pengampu**: Mahmud Suyuti, M.Kom
* **Judul Aplikasi**: **LaporYuk! – Aplikasi Pelaporan Fasilitas Publik Berbasis Smart City**

---

### **1. PENJELASAN ALUR LOGIKA PROGRAM**

Aplikasi **LaporYuk!** dibangun menggunakan bahasa pemrograman Dart dengan framework Flutter, dengan menerapkan pola arsitektur **Clean Architecture** (pemisahan data, domain/logic, dan presentation) dan menggunakan **BLoC/Cubit** sebagai pengatur state aplikasi. 

Berikut adalah penjelasan detail mengenai alur logika program pada modul-modul utama:

#### **A. Alur Logika Autentikasi (Multi-Role & Mode Failover)**
1. **Startup (Cek Sesi)**: Saat aplikasi dibuka, `AuthCubit` memanggil fungsi `checkCurrentUser()`. Fungsi ini akan memeriksa apakah ada sesi login aktif di Firebase Authentication. Jika Firebase Auth tidak terkonfigurasi/offline, sistem akan memeriksa database lokal menggunakan **Hive** (`reports_box`).
2. **Registrasi (Register)**: Warga mengisi form nama, email, nomor HP, alamat, dan password. Sistem mendaftarkan akun ke Firebase. Secara otomatis, akun warga baru mendapatkan metadata `role: Warga`. Data profil juga dicadangkan di Hive box `users_box`. Registrasi dibatasi agar tidak dapat menggunakan domain email khusus pemerintah `@lapor.go.id`.
3. **Masuk (Login)**:
   - Jika email berakhiran `@lapor.go.id`, sistem secara otomatis mengategorikan user sebagai **Petugas** (role: Petugas). Sesi login disimpan secara lokal dan online.
   - Jika email umum, sistem mendeteksi role sebagai **Warga** melalui database Firebase/Hive.
   - Setelah sukses masuk, `AuthCubit` memancarkan state `AuthAuthenticated` yang membawa data email, nama lengkap, dan role. `main.dart` mendeteksi perubahan state dan mengarahkan tampilan ke `DashboardPage`.

#### **B. Alur Logika Feed Laporan & Caching (Offline-First)**
1. Ketika `DashboardPage` dibuka, `ReportsCubit` memanggil `fetchReports()` untuk memuat data.
2. Logika data dikendalikan oleh `ReportRepository`:
   - **Kondisi Online**: Repositori meminta data ke REST API server via `RemoteApiClient.getReports()`. Setelah mendapat response JSON dari API, data di-caching (disimpan) ke Hive box `reports_box`. Kemudian data tersebut digabungkan (*merge*) dengan draf laporan offline yang belum terkirim di lokal.
   - **Kondisi Offline**: Jika koneksi gagal (melempar `DioException`), repositori menangkap error dan beralih ke cache lokal dengan memanggil `localStorageService.getCachedReports()`. Dengan demikian, daftar laporan lama tetap tampil di layar meskipun tanpa koneksi internet.

#### **C. Alur Logika Pembuatan Laporan (Kamera, GPS, & Offline Queue)**
1. Warga menekan tombol tambah (`+`) di dashboard.
2. Di halaman `CreateReportPage`, warga mengisi judul, deskripsi, dan memilih kategori laporan.
3. **Kamera**: Warga mengambil foto bukti kerusakan menggunakan package `image_picker`. Gambar dikonversi menjadi string Base64 agar dapat disimpan dengan mudah di database lokal (Hive) maupun dikirim ke server.
4. **GPS**: Warga menekan tombol "Dapatkan Lokasi GPS". Sistem menggunakan package `geolocator` untuk berinteraksi dengan sensor GPS perangkat keras HP guna mendapatkan koordinat latitude dan longitude terkini. Jika akses lokasi ditolak, sistem memiliki *fallback safety* otomatis ke koordinat Kampus UNTAG Surabaya.
5. **Penyimpanan Laporan**:
   - **Kondisi Online**: Laporan dikirim langsung ke REST API server menggunakan metode HTTP **POST**.
   - **Kondisi Offline**: Jika pengiriman gagal karena tidak ada koneksi, repositori akan menangkap `SocketException` dan menyimpan laporan ke dalam Hive box `offline_queue_box` (antrean offline). Laporan ini ditandai dengan flag `isSynced = false` dan ikon ☁️-off di Feed.

#### **D. Alur Sinkronisasi Offline (Sync)**
1. Ketika warga kembali mendapatkan jaringan internet, mereka dapat menekan ikon **Sync** (sinkronisasi) di bar atas dashboard.
2. `ReportsCubit` memanggil `syncOfflineReports()` pada repositori.
3. Repositori mengiterasi seluruh laporan dalam `offline_queue_box`, lalu mengirimkannya satu per satu ke server API via HTTP **POST**.
4. Setelah sukses terkirim, laporan tersebut dihapus dari antrean offline lokal dan cache lokal diperbarui dengan memanggil API `GET` terbaru.

#### **E. Alur Tindakan Petugas (HTTP PUT)**
1. Petugas masuk dengan akun berdomain `@lapor.go.id`. Dashboard menampilkan filter status (*Semua, Menunggu, Diproses, Selesai*).
2. Petugas memilih salah satu laporan warga untuk masuk ke `ReportDetailPage`.
3. Petugas menekan tombol **Simulasi Aksi Petugas**. Aplikasi mengirimkan request HTTP **PUT** ke REST API (`/reports/{id}`) untuk memperbarui status laporan (misalnya dari *Menunggu* menjadi *Diproses*, atau *Diproses* menjadi *Selesai*).
4. Setelah update berhasil di server, aplikasi menyegarkan (*refresh*) data dashboard sehingga progres laporan terbaru langsung terlihat oleh warga.

---

### **2. PANDUAN SCREENSHOT ANTARMUKA APLIKASI (MINIMAL 2 KONDISI BERBEDA)**

*Petunjuk untuk Mahasiswa: Silakan ambil tangkapan layar (screenshot) dari emulator/perangkat fisik Anda dan tempelkan di bagian ini.*

#### **Kondisi A: Dashboard Warga (Menampilkan Draf Offline)**
* **Deskripsi**: Screenshot ini menunjukkan antarmuka dashboard warga saat melaporkan dalam kondisi offline. Perhatikan adanya banner peringatan berwarna oranye di bagian atas feed dan ikon **cloud off** (awan tercoret) di sebelah kanan status "Menunggu" pada kartu laporan baru. Ini membuktikan fitur *Local Storage* dan *Offline Queue* berjalan sempurna.
* **[TEMPELKAN SCREENSHOT DASHBOARD WARGA OFFLINE DI SINI]**

#### **Kondisi B: Dashboard Petugas (Menampilkan Fitur Filter & Update Status)**
* **Deskripsi**: Screenshot ini menunjukkan tampilan dashboard ketika login sebagai Petugas (menggunakan email `@lapor.go.id`). Terlihat adanya bilah filter status (*Semua, Menunggu, Diproses, Selesai*) di bawah tab bar, serta tombol tindakan pembaruan status laporan di halaman detail. Ini membuktikan fungsionalitas multi-role berjalan dengan baik.
* **[TEMPELKAN SCREENSHOT DASHBOARD PETUGAS & UPDATE STATUS DI SINI]**

#### **Kondisi C: Form Input Laporan dengan Kamera & Deteksi GPS**
* **Deskripsi**: Screenshot yang menampilkan form pengisian laporan baru lengkap dengan pratinjau gambar kerusakan dari kamera/galeri serta koordinat latitude/longitude yang berhasil dideteksi dari GPS perangkat.
* **[TEMPELKAN SCREENSHOT FORM TAMBAH LAPORAN DI SINI]**

---

### **3. PRASYARAT DAN TAUTAN LUARAN (YANG HARUS DIKUMPULKAN)**

#### **A. Tautan Repositori GitHub/GitLab**
* **Link Repositori**: [Isi Tautan Link Repositori GitHub Anda yang sudah diset ke Publik]
* *Catatan: Pastikan struktur kode rapi dan file README.md sudah memuat dokumentasi arsitektur.*

#### **B. Tautan Video Demonstrasi Aplikasi**
* **Link Video**: [Isi Tautan Link Google Drive / YouTube yang di-set ke Publik]
* **Durasi Video**: Maksimal 5 Menit
* *Daftar Alur Video Demo yang Direkomendasikan untuk Direkam:*
  1. **Registrasi Akun Warga Baru**: Rekam proses daftar warga baru dengan validasi form (semua kolom terisi).
  2. **Login Akun Warga & Halaman Profil**: Tunjukkan tampilan dashboard dan popup profil warga yang berhasil masuk.
  3. **Buat Laporan Baru (Kondisi Online)**: Rekam proses pengisian laporan, pengambilan foto melalui kamera/galeri, menekan tombol deteksi GPS lokasi (koordinat muncul), dan mengirim laporan. Tunjukkan laporan baru langsung muncul di feed teratas.
  4. **Simulasi Offline Mode**: Matikan Wi-Fi/Koneksi Internet pada emulator/HP. Buat laporan baru lagi. Tunjukkan bahwa aplikasi tidak crash, melainkan menampilkan snackbar bahwa laporan disimpan sebagai draf offline. Tunjukkan ikon awan tercoret di kartu laporan tersebut.
  5. **Simulasi Sinkronisasi (Sync)**: Nyalakan kembali koneksi internet. Klik tombol **Sync** di bar atas. Tunjukkan draf laporan offline berhasil diunggah ke server dan ikon awan tercoret hilang.
  6. **Login Akun Petugas**: Keluar dari akun warga, lalu login menggunakan akun berdomain `@lapor.go.id` (Contoh: `admin@lapor.go.id`).
  7. **Filter & Update Status**: Tunjukkan penggunaan filter status laporan di dashboard petugas. Klik detail laporan warga, tekan tombol **Simulasi Aksi Petugas** untuk memperbarui status (misal dari *Menunggu* ke *Diproses* atau *Selesai*). Tunjukkan perubahan warna status.

#### **C. Tautan Unduh File Executable (APK)**
* **Link APK**: [Isi Tautan Link Google Drive untuk mendownload file APK hasil build]
* *Perintah build APK rilis di terminal:*
  ```bash
  flutter build apk --release
  ```
  *Kirimkan file `app-release.apk` hasil build di folder `build/app/outputs/flutter-apk/` ke Google Drive Anda dan bagikan link-nya dengan akses "Siapa saja yang memiliki link dapat melihat".*
