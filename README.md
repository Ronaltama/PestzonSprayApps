<![CDATA[<div align="center">

# 🌿 Pestzon Spray App
### Smart Sprayer AI & IoT — v1.0.1

**Offline-First & Cloud-Enabled Automatic Solar-Powered Spraying System**

[![GitHub Repo](https://img.shields.io/badge/GitHub-PestzonSprayApps-2ea44f?logo=github)](https://github.com/Ronaltama/PestzonSprayApps)
[![Flutter](https://img.shields.io/badge/Flutter-v3.13-02569B?logo=flutter)](https://flutter.dev)
[![ESP32](https://img.shields.io/badge/Firmware-ESP32%20Arduino-E7352C?logo=arduino)](https://www.espressif.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

</div>

---

## 📖 Tentang Proyek Ini

**Pestzon Spray App** adalah sistem penyemprotan otomatis berbasis **ESP32-WROOM-32** yang dirancang untuk kebutuhan pertanian dan lingkungan luar ruangan dengan keterbatasan akses internet.

Sistem menggunakan pendekatan **Offline-First via Bluetooth Low Energy (BLE)** dan mendukung **Monitoring & Kontrol Jarak Jauh via MQTT** ketika koneksi internet tersedia — sehingga alat tetap dapat beroperasi secara mandiri tanpa internet, sekaligus bisa ditingkatkan menjadi perangkat IoT penuh.

---

## 🏗️ Arsitektur Sistem

```
┌─────────────────────────────────────────────────────┐
│                  PESTZON SPRAY APP                  │
│              (Flutter Android / iOS)                │
└──────────────┬──────────────────────┬───────────────┘
               │ BLE (Offline)        │ MQTT (Online)
               ▼                      ▼
┌──────────────────────┐    ┌──────────────────────┐
│   ESP32 Smart        │◄──►│  Cloud MQTT Broker   │
│   Sprayer (Firmware) │    │  (broker.emqx.io)    │
└──────────────────────┘    └──────────────────────┘
         │
    ┌────┴─────┐
    │ Hardware │
    │ • Relay  │
    │ • Pompa  │
    │ • LED    │
    └──────────┘
```

**Mode BLE (Offline):** Digunakan ketika berada dekat dengan alat.
**Mode MQTT (Online):** Digunakan untuk monitoring & kontrol dari mana saja via internet.

---

## ✨ Fitur Utama

| Fitur | Deskripsi | Mode |
|-------|-----------|------|
| 📊 **Dashboard** | Status real-time: baterai, sesi, volume hari ini | BLE / MQTT |
| 📶 **BLE Pairing** | Scan & koneksi otomatis ke ESP32 | BLE |
| 🎮 **Manual Spray** | Kontrol pompa manual dengan durasi custom | BLE / MQTT |
| ⏰ **Jadwal Otomatis** | Jadwal harian tersimpan di ESP32 (tetap jalan tanpa HP) | BLE |
| 📜 **Riwayat Log** | History penyemprotan (tanggal, waktu, volume, mode) | BLE / MQTT |
| 📡 **Konfigurasi WiFi** | Kirim SSID & password ke ESP32 via BLE (non-blocking) | BLE |
| ⚖️ **Kalibrasi Pompa** | Atur debit ml/detik untuk hitung volume akurat | BLE |
| 💡 **Test Lampu Malam** | Toggle LED secara manual untuk pengujian instan | BLE |
| 🔄 **Auto-Dedup Log** | Mencegah entri riwayat ganda saat reconnect | BLE |

---

## 🔌 Spesifikasi Hardware

### Mikrokontroler
| Komponen | Keterangan |
|----------|------------|
| **ESP32-WROOM-32** | Mikrokontroler utama (BLE + WiFi) |
| **Relay Module** | PIN 23 — Kontrol pompa air |
| **LED Indicator** | PIN 4 — Lampu malam otomatis (18:00–05:59) |

### Sistem Daya (Solar)
| Komponen | Spesifikasi |
|----------|-------------|
| Solar Cell | 5V 2W 400mA |
| Battery Charger | TP4056 with Protection |
| Baterai | 18650 × 2, kapasitas 1500mAh |
| Voltage Regulator | AMS1117 3.3V |

### Sistem Pompa
| Komponen | Keterangan |
|----------|------------|
| Pompa Air | Mini Water Pump 310 DC 5V |
| Nozzle | Misting Nozzle |
| Pipa | PVC 22mm + Tee Connector |

---

## 📱 Halaman Aplikasi

```
Pestzon Spray App
├── 🏠  Dashboard       → Status real-time semua perangkat
├── 📶  Devices         → Scan BLE, Pairing, Konfigurasi WiFi/MQTT
│   └── Detail Device
│       ├── 📋 Ringkasan → Volume, Baterai, Sesi + Test Lampu Malam
│       ├── ⏰ Jadwal   → Buat / Edit / Hapus jadwal per perangkat
│       └── 📜 Riwayat  → History log semprotan per perangkat
├── 🎮  Kontrol         → Manual spray + slider durasi
├── 📅  Jadwal Global   → Semua jadwal lintas perangkat
└── ⚙️  Pengaturan      → Tema, Kalibrasi, Notifikasi
```

---

## 📡 Protokol Komunikasi BLE

### Perintah dari App → ESP32

| Command | Deskripsi | Contoh Payload |
|---------|-----------|----------------|
| `SPRAY` | Mulai semprot | `{"cmd":"SPRAY","duration":30}` |
| `STOP` | Hentikan pompa | `{"cmd":"STOP"}` |
| `CONFIG` / `set_wifi` | Kirim konfigurasi WiFi | `{"cmd":"CONFIG","ssid":"...","password":"..."}` |
| `set_schedules` | Kirim semua jadwal | `{"cmd":"set_schedules","schedules":[...]}` |
| `toggle_led` | Nyala/mati LED manual | `{"cmd":"toggle_led","state":true}` |
| `set_calibration` | Kalibrasi debit pompa | `{"cmd":"set_calibration","flowRate":15.0}` |
| `time_sync` | Sinkronisasi jam | `{"cmd":"time_sync","ts":1725000000}` |

### Data dari ESP32 → App

| Type | Deskripsi |
|------|-----------|
| `summary` | Status perangkat (baterai, volume, sesi) |
| `log` | Notifikasi setelah selesai semprot |
| `schedules` | Daftar jadwal aktif |
| `ack` | Konfirmasi perintah diterima |

---

## ☁️ Topik MQTT

```
pestzon/{device_id}/cmd        ← App kirim perintah ke ESP32
pestzon/{device_id}/status     → ESP32 publish status
pestzon/{device_id}/log        → ESP32 publish riwayat semprot
pestzon/{device_id}/response   → ESP32 publish respons perintah
```

> Default Broker: `broker.emqx.io` — bisa diubah dari aplikasi.

---

## 📁 Struktur Folder Project

```
FetCoreApp/
├── lib/
│   ├── models/          → Device, Log, Schedule, Snapshot
│   ├── services/        → BluetoothService, DatabaseHelper, DeviceRepository
│   ├── screens/         → Dashboard, Devices, Detail, Schedule, History
│   ├── theme/           → AppTheme, ThemeProvider
│   └── main.dart
├── firmware/
│   └── esp32_smart_sprayer/
│       └── esp32_smart_sprayer.ino   ← Firmware Arduino ESP32
├── assets/
│   └── icon/
├── MANUAL_BOOK.md       ← 📖 Panduan pengguna lengkap
└── README.md
```

---

## 🚀 Cara Setup & Menjalankan

### 1. Clone Repositori
```bash
git clone https://github.com/Ronaltama/PestzonSprayApps.git
cd PestzonSprayApps
```

### 2. Install Dependensi Flutter
```bash
flutter pub get
```

### 3. Upload Firmware ke ESP32
Buka file `firmware/esp32_smart_sprayer/esp32_smart_sprayer.ino` di Arduino IDE.

Install library berikut via Library Manager:
- `ArduinoJson` (v6 / v7)
- `PubSubClient` (by Nick O'Leary)

Pilih board **ESP32 Dev Module**, lalu klik **Upload**.

### 4. Build & Install APK
```bash
flutter build apk
# File APK: build/app/outputs/flutter-apk/app-release.apk
```

---

## ⚙️ Tech Stack

| Layer | Teknologi |
|-------|-----------|
| **Mobile App** | Flutter (Dart), Provider |
| **Database Lokal** | SQLite (sqflite) |
| **Bluetooth** | flutter_blue_plus |
| **MQTT Client** | mqtt_client |
| **Notifikasi** | flutter_local_notifications |
| **Firmware** | ESP32 Arduino Framework |
| **Wireless** | BLE (Bluetooth Low Energy) + WiFi |
| **Cloud Messaging** | MQTT (PubSubClient) |
| **Storage ESP32** | NVS (Non-Volatile Storage / Preferences) |

---

## 📄 Dokumentasi Lengkap

Lihat [**MANUAL_BOOK.md**](./MANUAL_BOOK.md) untuk panduan pengguna lengkap, termasuk:
- Cara instalasi & pairing
- Kalibrasi pompa
- Panduan jadwal otomatis
- Troubleshooting

---

## 📄 Lisensi

Proyek ini menggunakan lisensi **MIT**. Silakan digunakan dan dimodifikasi sesuai kebutuhan.

---

<div align="center">

**🌿 Pestzon Spray App**

*Offline-First Smart Agriculture Spraying System*
*powered by ESP32 · BLE · MQTT · Solar Energy*

© 2026 Ronaltama — [github.com/Ronaltama/PestzonSprayApps](https://github.com/Ronaltama/PestzonSprayApps)

</div>
]]>
