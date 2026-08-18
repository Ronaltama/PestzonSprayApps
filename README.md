# Smart Agriculture Flutter App (Pertanian App) 🌾📱

Aplikasi Flutter untuk **Smart Agriculture / Pertanian Digital** yang dirancang dengan pendekatan *Offline-First*. Aplikasi ini mampu membaca sensor pertanian secara langsung via **Bluetooth Low Energy (BLE)**, menyimpan data pembacaan secara lokal (**Local Storage**), dan mengirimkan data ke Server Cloud ketika terhubung ke **Wi-Fi** atau internet.

---

## 🛠️ Fitur Utama & Paket yang Terpasang

- 📦 **Local Storage (Offline-First Database)**
  - `hive` & `hive_flutter`: Database NoSQL lokal yang sangat cepat & ringan untuk menyimpan riwayat sensor (suhu, kelembapan tanah, pH, dll.) di perangkat tanpa koneksi internet.
  - `shared_preferences`: Untuk menyimpan pengaturan aplikasi & konfigurasi sensor.
  - `path_provider`: Mengelola akses direktori sistem berkas lokal.

- 📶 **Komunikasi Bluetooth (BLE)**
  - `flutter_blue_plus`: Digunakan untuk memindai (*scan*), menautkan (*pair*), dan membaca data telemetry dari node sensor kebun/pertanian secara langsung.

- 🌐 **Wi-Fi & Networking**
  - `dio`: Client HTTP modern untuk mengirimkan data hasil pembacaan sensor ke REST API / Web Server.
  - `connectivity_plus`: Mendeteksi perubahan status koneksi Wi-Fi/Internet secara real-time.

---

## 🚀 Cara Menjalankan Aplikasi

Pastikan kamu berada di direktori project `Flutter-Apps-1`:

```bash
cd "/home/ronaltama/PROJECT/MAS PERDANA/Flutter-Apps-1"
```

### 1. Jalankan di Desktop Linux (CachyOS)
Sangat cocok untuk testing cepat antarmuka UI tanpa memerlukan emulator/HP:

```bash
flutter run -d linux
```

### 2. Jalankan di Perangkat HP Android
1. Aktifkan **USB Debugging** pada HP Android kamu.
2. Sambungkan HP ke laptop/PC via kabel USB.
3. Cek perangkat terdeteksi dengan perintah:
   ```bash
   flutter devices
   ```
4. Jalankan aplikasi ke HP Android:
   ```bash
   flutter run
   ```

### 3. Jalankan di Web Browser (Chromium / Chrome)
```bash
flutter run -d chrome
```

---

## ⚙️ Perintah-Perintah Penting (Useful Commands)

- **Mengambil / Memperbarui Package**:
  ```bash
  flutter pub get
  ```

- **Mengecek Analisis Kode & Syntax Error**:
  ```bash
  flutter analyze
  ```

- **Mengecek Kesehatan Lingkungan Flutter**:
  ```bash
  flutter doctor
  ```

- **Build APK Android (Release)**:
  ```bash
  flutter build apk --release
  ```
  *Hasil APK akan tersimpan di: `build/app/outputs/flutter-apk/app-release.apk`*

---

## 📁 Struktur Direktori Utama

```text
Flutter-Apps-1/
├── android/            # Konfigurasi & build khusus Android
├── linux/              # Konfigurasi & build khusus Linux Desktop
├── lib/                # Kode utama aplikasi (Dart)
│   └── main.dart       # Entry point utama aplikasi
├── pubspec.yaml        # Konfigurasi dependensi & package Flutter
└── README.md           # Dokumentasi petunjuk penggunaan
```

---

*Dikembangkan untuk lingkungan CachyOS Linux menggunakan Editor Zed / Antigravity.*
