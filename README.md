# 🌿 Smart Sprayer AI & IoT

**Offline-First & Cloud-Enabled Automatic Solar-Powered Spraying System**

Smart Sprayer AI & IoT adalah sistem penyemprotan otomatis berbasis **ESP32-WROOM-32** yang dirancang untuk kebutuhan pertanian dan lingkungan luar ruangan dengan keterbatasan akses internet. Sistem mengadopsi pendekatan **Offline-First melalui Bluetooth Low Energy (BLE)** serta mendukung **Monitoring dan Kontrol Jarak Jauh melalui MQTT** ketika koneksi internet tersedia.

Dengan pendekatan ini, alat tetap dapat beroperasi secara mandiri tanpa internet, sekaligus dapat ditingkatkan menjadi perangkat IoT penuh untuk pemantauan dan pengendalian dari mana saja.

---

# 🚀 Value Proposition

Sebagian besar solusi IoT pertanian bergantung pada koneksi internet yang stabil. Smart Sprayer AI & IoT dirancang untuk mengatasi permasalahan tersebut dengan menyediakan dua mode operasi:

### 📶 Offline Mode (BLE)

Digunakan ketika pengguna berada di dekat alat.

* Pairing perangkat
* Konfigurasi alat
* Sinkronisasi data
* Pengaturan jadwal
* Kontrol manual pompa
* Monitoring status perangkat

### ☁️ Online Mode (MQTT)

Digunakan ketika perangkat terhubung ke internet.

* Monitoring jarak jauh
* Kontrol pompa dari mana saja
* Sinkronisasi status perangkat
* Pengiriman log penyemprotan
* Update konfigurasi tanpa mendatangi lokasi alat

---

# 🏗️ Arsitektur Sistem

```text
                 Internet
                     │
                     ▼
             MQTT Broker
                     ▲
                     │
        ┌──────────────────────┐
        │ Flutter Application  │
        └──────────────────────┘
             ▲            ▲
             │ BLE        │ MQTT
             │            │
        ┌──────────────────────┐
        │ ESP32 Smart Sprayer  │
        └──────────────────────┘
```

### Saat Offline

```text
Flutter App
     │
Bluetooth BLE
     │
ESP32
```

### Saat Online

```text
Flutter App
     │
Internet
     │
MQTT Broker
     │
Internet
     │
ESP32
```

Pengguna tidak perlu mengetahui apakah aplikasi sedang menggunakan BLE atau MQTT. Sistem akan memilih metode komunikasi yang tersedia secara otomatis.

---

# ✨ Fitur Utama

## 📊 Dashboard Monitoring

Menampilkan informasi perangkat secara real-time:

* Status perangkat
* Status koneksi
* Persentase baterai
* Tegangan baterai
* Status pengisian daya panel surya
* Riwayat penyemprotan terakhir
* Total aktivitas penyemprotan

---

## 📶 Device Management

Mengelola koneksi dan konfigurasi perangkat.

Fitur:

* Scan perangkat BLE
* Pairing ESP32
* Sinkronisasi data
* Konfigurasi WiFi
* Konfigurasi MQTT
* Kalibrasi alat
* Informasi perangkat

---

## 🎮 Manual Control

Kontrol penyemprotan secara langsung.

Fitur:

* Start Spray
* Stop Spray
* Pengaturan durasi semprot
* Monitoring status pompa

---

## ⏰ Automatic Scheduling

Mengatur jadwal penyemprotan otomatis yang disimpan langsung pada ESP32.

Contoh:

```text
07:00 - 30 Detik
12:00 - 15 Detik
16:00 - 20 Detik
```

Jadwal tetap berjalan meskipun:

* HP dimatikan
* Bluetooth tidak aktif
* Tidak ada koneksi internet

---

## 📜 History & Analytics

Riwayat aktivitas penyemprotan tersimpan pada database lokal aplikasi.

Data yang disimpan:

* Tanggal
* Waktu
* Durasi semprot
* Status penyemprotan
* Status baterai
* Metode komunikasi (BLE/MQTT)

---

# 🗄️ Database Strategy

Sistem menggunakan pendekatan hybrid storage.

## ESP32

Menyimpan:

* Konfigurasi perangkat
* Jadwal penyemprotan
* Informasi WiFi
* Informasi MQTT
* Buffer log sementara

Media penyimpanan:

```text
ESP32 NVS (Non Volatile Storage)
```

---

## Smartphone

Menyimpan:

* Riwayat penyemprotan
* Data statistik
* Cache status perangkat
* Konfigurasi aplikasi

Media penyimpanan:

```text
SQLite
```

---

# 📡 MQTT Communication

MQTT digunakan hanya ketika perangkat berhasil terhubung ke internet.

## Device Topic Structure

```text
sprayer/{device_id}/status
sprayer/{device_id}/command
sprayer/{device_id}/config
sprayer/{device_id}/log
```

Contoh:

```text
sprayer/SPRAYER-001/status
sprayer/SPRAYER-001/command
sprayer/SPRAYER-001/config
sprayer/SPRAYER-001/log
```

---

## Publish Topics

ESP32 mengirim data ke:

```text
sprayer/{device_id}/status
sprayer/{device_id}/log
```

---

## Subscribe Topics

ESP32 menerima perintah dari:

```text
sprayer/{device_id}/command
sprayer/{device_id}/config
```

---

## Contoh Command

Topic:

```text
sprayer/SPRAYER-001/command
```

Payload:

```json
{
  "action": "spray",
  "duration": 30
}
```

---

# 📱 Struktur Halaman Aplikasi

## 1. Dashboard

Monitoring perangkat secara real-time.

---

## 2. Devices

Manajemen perangkat dan konfigurasi.

---

## 3. Control

Kontrol penyemprotan manual.

---

## 4. Schedule

Manajemen jadwal otomatis.

---

## 5. History

Riwayat dan statistik penyemprotan.

---

# 📁 Struktur Folder Project

```text
lib/
│
├── models/
│   ├── device_status.dart
│   ├── spray_log.dart
│   ├── spray_schedule.dart
│
├── services/
│   ├── bluetooth_service.dart
│   ├── mqtt_service.dart
│   ├── database_service.dart
│   └── storage_service.dart
│
├── repositories/
│   ├── device_repository.dart
│   ├── history_repository.dart
│   └── schedule_repository.dart
│
├── screens/
│   ├── dashboard/
│   ├── devices/
│   ├── control/
│   ├── schedule/
│   └── history/
│
├── widgets/
│
├── providers/
│
├── theme/
│
└── main.dart
```

---

# 🔌 Supported Hardware

## Microcontroller

* ESP32-WROOM-32

---

## Power System

* Solar Cell 5V 2W 400mA
* TP4056 Battery Charger with Protection
* 18650 Battery 2x 1500mAh
* AMS1117 3.3V Voltage Regulator

---

## Pump System

* Mini Water Pump 310 DC 5V
* Misting Nozzle
* Tee Connector
* PVC Pipe 22mm

---

## Supporting Components

* UV LED 5mm
* LED Indicator 2835 SMD
* Capacitor 100nF
* Resistor 10KΩ
* Resistor 4.7KΩ
* Resistor 680Ω
* Resistor 220Ω–330Ω
* Pin Header Male/Female
* Custom PCB
* Prototype PCB
* AWG22 Cable
* 3D Printed Enclosure

---

# 🔄 Initial Setup Flow

```text
Install Application
        │
        ▼
Scan Device BLE
        │
        ▼
Pair ESP32
        │
        ▼
Set Device Name
        │
        ▼
Configure WiFi
        │
        ▼
Sync Configuration
        │
        ▼
ESP32 Connect WiFi
        │
        ▼
ESP32 Connect MQTT
        │
        ▼
Device Online
```

---

# ⚙️ Technology Stack

## Mobile App

* Flutter
* Dart
* Provider / Riverpod
* SQLite
* Flutter Blue Plus
* MQTT Client

---

## Firmware

* ESP32 Arduino Framework
* BLE Server
* WiFi Manager
* PubSubClient MQTT
* Preferences (NVS)

---

# 🎯 MVP Scope

Versi pertama sistem akan fokus pada:

* Bluetooth BLE Communication
* WiFi Configuration
* MQTT Communication
* Manual Spray Control
* Automatic Scheduling
* Battery Monitoring
* Solar Charging Monitoring
* Local Data Storage
* History Synchronization
* Dashboard Monitoring

---

# 📄 License

MIT License

---

**Smart Sprayer AI & IoT**

*Offline-First Smart Agriculture Spraying System powered by ESP32, BLE, MQTT, and Solar Energy.*
