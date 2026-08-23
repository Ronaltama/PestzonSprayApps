# 🌿 Alburdat Presisi - Sistem Kontrol & Monitoring Pemupukan Presisi IoT

[![Flutter](https://img.shields.io/badge/Flutter-3.11.1+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![MQTT](https://img.shields.io/badge/MQTT-v3.1.1-660099?style=for-the-badge&logo=mqtt&logoColor=white)](https://mqtt.org)
[![Platform](https://img.shields.io/badge/Platform-Linux%20|%20Android%20|%20iOS%20|%20Web%20|%20Windows%20|%20macOS-blue?style=for-the-badge)](https://flutter.dev)

**Alburdat Presisi** adalah aplikasi kontrol & monitoring IoT (*Internet of Things*) untuk alat pemberi pupuk otomatis berbasis mikrokontroler (ESP32). Aplikasi ini dirancang untuk mendukung **Pertanian Presisi (*Precision Agriculture*)** dengan mengintegrasikan **Sistem Pakar (*Expert System / Rule-Based AI*)** untuk kalkulasi pemupukan otomatis berdasarkan komoditas dan usia tanaman.

---

## 📌 Mengapa Ada AI / Sistem Pakar di Aplikasi Ini?

Di bidang pertanian, dosis pupuk yang terlalu sedikit (*under-fertilization*) membuat tanaman kerdil, sedangkan dosis berlebih (*over-fertilization*) dapat merusak tanah dan membakar akar tanaman. Penentuan dosis ideal memerlukan perhitungan akurat berdasarkan:
- **Jenis Komoditas** (Jagung, Sawit, Kopi, Durian, dll.)
- **Umur Tanaman dalam HST** (*Hari Setelah Tanam*)
- **Jenis Pupuk** (NPK, Urea, dll.)
- **Jumlah Tanaman & Jarak Tanam**

Aplikasi ini menggunakan **Sistem Pakar berbasis Aturan (*Rule-Based Expert System*)** di `lib/services/expert_system_service.dart` dan `lib/data/knowledge_base.dart`. 
Sistem ini bertindak sebagai **"Pakar Agronomi Digital"** yang secara otomatis:
1. Memadankan usia tanaman (HST) dengan aturan agrikultur spesifik.
2. Mengalikan bobot pupuk dengan *multiplier factor* jenis pupuk.
3. Menghitung akumulasi total gram pupuk yang dibutuhkan seluruh lahan.
4. Mengirimkan dosis presisi tersebut langsung ke perangkat IoT ESP32 via MQTT.

---

## 🔄 Alur Aplikasi (App Flow) & Use Cases

```
┌─────────────────────────────────────────────────────────┐
│              Buka Aplikasi Flutter Dashboard            │
└───────────────────────────┬─────────────────────────────┘
                            │
            Auto-Connect ke Broker MQTT (broker.emqx.io)
                            │
       ┌────────────────────┼────────────────────┐
       ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Mode 1:     │    │  Mode 2:     │    │  Mode 3:     │
│ Rekomendasi  │    │ Kontrol      │    │ Konfigurasi  │
│  Sistem      │    │ Dosis Manual │    │ WiFi Device  │
│   Pakar      │    │ (Gram/Slider)│    │   (Reset)    │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │ Kirim Command JSON via MQTT
                           ▼
             ┌──────────────────────────┐
             │    MQTT Server / Broker  │
             └─────────────┬────────────┘
                           │ Telemetri & Exec
                           ▼
             ┌──────────────────────────┐
             │ Perangkat ESP32 Hardware │
             │ - Dispenser Motor        │
             │ - Screen OLED            │
             │ - Storage EEPROM         │
             └─────────────┬────────────┘
                           │ Feedback Status Real-time
                           ▼
             ┌──────────────────────────┐
             │  Dashboard UI Monitoring │
             │  - Real-time Status      │
             │  - Grafik fl_chart       │
             └──────────────────────────┘
```

### 🎯 Main Use Cases:
1. **Rekomendasi Pemupukan Otomatis**: Petani tidak perlu menghitung dosis manual. Cukup pilih jenis tanaman dan masukkan berapa hari usianya (HST), sistem pakar akan menentukan dosis paling optimal.
2. **Eksekusi Pemupukan Jarak Jauh**: Mengirimkan sinyal pemupukan (gram/ml) langsung ke mesin dispenser pupuk di lapangan via internet/MQTT.
3. **Monitoring & Tracking Telemetri**: Memantau status aktif motor dispenser, konektivitas alat, serta grafik statistik akumulasi pemupukan harian.
4. **Manajemen Jaringan Alat**: Melakukan reset/rekonfigurasi WiFi ESP32 langsung melalui aplikasi tanpa perlu membongkar alat.

---

## 🛠️ Teknologi & Stack yang Digunakan

- **Framework Frontend**: [Flutter](https://flutter.dev) (Dart SDK `^3.11.1`) - Suport multi-platform native.
- **State Management**: [Provider](https://pub.dev/packages/provider) (`^6.1.1`) - Manajemen state reaktif untuk status device & koneksi MQTT.
- **Komunikasi Real-Time**: [mqtt_client](https://pub.dev/packages/mqtt_client) (`^10.11.9`) - Protokol publish/subscribe ringan berlatensi rendah.
- **Visualisasi Data**: [fl_chart](https://pub.dev/packages/fl_chart) (`^1.2.0`) - Grafik statistik penggunaan pupuk.
- **Rule Engine (AI)**: Pure Dart Expert System (`knowledge_base.dart` & `ExpertSystemService`).
- **UI & Animasi**: `google_fonts`, `lottie`, `flutter_svg`.
- **Target Hardware**: ESP32 dengan firmware dispenser pupuk, motor DC/stepper, layar OLED & EEPROM.

---

## 📁 Struktur Folder Project

```text
lib/
├── data/
│   └── knowledge_base.dart        # Agronomy Knowledge Base (Rules 13+ komoditas & multiplier pupuk)
├── models/
│   ├── calculation_input.dart     # Data model input rekomendasi
│   ├── calculation_result.dart    # Data model hasil kalkulasi dosis
│   ├── commodity.dart             # Master data komoditas & jarak tanam
│   ├── device_status.dart         # Status telemetri ESP32 (motor, dosis, stats)
│   ├── fertilizer.dart            # Master data jenis pupuk
│   └── rule.dart                  # Model aturan Sistem Pakar (HST min/max → dosis)
├── services/
│   ├── expert_system_service.dart # Engine Sistem Pakar (Kalkulator Dosis AI)
│   └── mqtt_service.dart          # Komunikasi MQTT Client & Auto-reconnect
├── screens/
│   ├── main_navigation_screen.dart # Navigasi utama (Bottom bar / Sidebar)
│   ├── dashboard_page.dart        # Monitoring status real-time & grafik
│   ├── rekomendasi_page.dart      # Form rekomendasi pemupukan berbasis AI
│   ├── manual_page.dart           # Kontrol dosis manual
│   ├── wifi_page.dart             # Konfigurasi WiFi device
│   └── info_page.dart             # Informasi sistem & instruksi
├── widgets/                       # Components UI reusabel (Cards, Charts, Gauges)
└── theme/                         # Color Palette & Typography design system
```

---

## ⚡ Cara Menjalankan Aplikasi

### Requirements:
- Flutter SDK `^3.11.1` atau lebih baru.
- Linux, macOS, Windows, Android, atau iOS.

### Langkah-langkah:
```bash
# 1. Install / update dependency
flutter pub get

# 2. Jalankan di Linux Desktop (Arch/CachyOS/Ubuntu/Fedora):
flutter run -d linux

# 3. Atau jalankan di Chrome Web Browser:
flutter run -d chrome

# 4. Atau jalankan di Android Device / Emulator:
flutter run
```

---

## 📚 Dokumentasi Lanjutan

- 📖 **[USER_GUIDE.md](docs/USER_GUIDE.md)** — Panduan penggunaan untuk petani/operator lapangan.
- ⚡ **[QUICK_START.md](docs/QUICK_START.md)** — Quick start panduan setup developer.
- 🏗️ **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** — Detail arsitektur MQTT & P2P payload.
- 🔧 **[DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md)** — Guide modifikasi aturan sistem pakar & komoditas baru.

---

**Maintainer**: Development Team  
**License**: MIT License
