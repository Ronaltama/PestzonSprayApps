<![CDATA[<div align="center">

# 📖 Manual Book
# Pestzon Spray App
### Smart Sprayer AI & IoT — v1.0.1

*Panduan Penggunaan Lengkap untuk Operator & Teknisi*

---

**Disiapkan untuk:** Pestzon Spray App v1.0.1  
**Platform:** Android  
**Hardware:** ESP32-WROOM-32 Smart Sprayer  
**Repository:** [github.com/Ronaltama/PestzonSprayApps](https://github.com/Ronaltama/PestzonSprayApps)

</div>

---

## 📋 Daftar Isi

| No | Bab | Halaman |
|----|-----|---------|
| 1 | [Persiapan Awal (Hardware)](#bab-1--persiapan-awal-hardware) | — |
| 2 | [Instalasi Aplikasi](#bab-2--instalasi-aplikasi) | — |
| 3 | [Menghubungkan Perangkat (Pairing)](#bab-3--menghubungkan-perangkat-pairing) | — |
| 4 | [Konfigurasi WiFi & Cloud](#bab-4--konfigurasi-wifi--cloud) | — |
| 5 | [Menyemprot secara Manual](#bab-5--menyemprot-secara-manual) | — |
| 6 | [Mengatur Jadwal Otomatis](#bab-6--mengatur-jadwal-otomatis) | — |
| 7 | [Melihat Riwayat Log](#bab-7--melihat-riwayat-log) | — |
| 8 | [Kalibrasi Debit Pompa](#bab-8--kalibrasi-debit-pompa) | — |
| 9 | [Fitur Testing Lampu Malam](#bab-9--fitur-testing-lampu-malam) | — |
| 10 | [Troubleshooting](#bab-10--troubleshooting) | — |

---

## BAB 1 — Persiapan Awal (Hardware)

Sebelum menggunakan aplikasi, pastikan modul **ESP32 Smart Sprayer** sudah terangkai dengan benar dan dalam kondisi bertenaga (dari baterai atau panel surya).

### Referensi Pin ESP32

| Pin | Fungsi | Keterangan |
|-----|--------|------------|
| **PIN 23** | Relay Pompa | Terhubung ke modul relay untuk mengontrol pompa air |
| **PIN 4** | LED Malam | Lampu otomatis menyala pukul 18:00–05:59 |

### Checklist Sebelum Menyalakan

- [ ] Catu daya terpasang (baterai atau USB)
- [ ] Pompa air terhubung ke relay di PIN 23
- [ ] LED terhubung di PIN 4
- [ ] Firmware sudah di-upload ke ESP32

### Indikator Alat Sudah Siap

Setelah ESP32 dinyalakan, alat akan memancarkan sinyal Bluetooth dengan nama:

```
ESP32_Sprayer
```

Nama ini akan terdeteksi di menu scan aplikasi.

---

## BAB 2 — Instalasi Aplikasi

### Persyaratan Sistem
- Smartphone Android versi 6.0 (Marshmallow) ke atas
- Bluetooth & Location Service aktif
- RAM minimal 2GB (rekomendasi 3GB)

### Langkah Instalasi

1. Transfer file **`app-release.apk`** ke HP Anda (via kabel, WhatsApp, dll).
2. Buka aplikasi **File Manager** di HP, lalu cari file tersebut.
3. Ketuk file untuk memulai instalasi.
4. Jika muncul peringatan *"Install from Unknown Sources"*, ketuk **Izinkan / Allow**.
5. Ketuk **Install** dan tunggu proses selesai.
6. Buka aplikasi **Pestzon Spray App**.

### Izin yang Diperlukan

Saat pertama kali dibuka, aplikasi akan meminta izin berikut — pastikan semua **diizinkan**:

| Izin | Alasan |
|------|--------|
| 📍 **Lokasi (Location)** | Wajib untuk scan perangkat BLE di Android |
| 📶 **Bluetooth** | Untuk berkomunikasi dengan ESP32 |
| 🔔 **Notifikasi** | Untuk pemberitahuan jadwal & status semprot |

---

## BAB 3 — Menghubungkan Perangkat (Pairing)

### Langkah Pairing BLE

1. Buka aplikasi Pestzon Spray App.
2. Navigasi ke menu **Devices** (ikon perangkat di navigasi bawah).
3. Ketuk tombol **"Scan Perangkat"** atau ikon scan.
4. Tunggu beberapa detik — nama **`ESP32_Sprayer`** akan muncul dalam daftar.
5. Ketuk nama perangkat tersebut.
6. Tunggu hingga status berubah menjadi **🟢 LIVE** di pojok kanan atas.

### Yang Terjadi Saat Pertama Kali Terhubung

Begitu koneksi berhasil, aplikasi secara otomatis akan:

- ✅ Menyinkronkan **Jam & Tanggal** dari HP ke ESP32
- ✅ Menarik **data status** (baterai, sesi, volume) dari ESP32
- ✅ Menarik **riwayat log** terbaru dari ESP32

> **Catatan:** Jangkauan koneksi BLE adalah sekitar **5–10 meter** dalam kondisi normal (bisa berkurang di area logam atau beton tebal).

---

## BAB 4 — Konfigurasi WiFi & Cloud

Fitur ini memungkinkan ESP32 terhubung ke internet agar bisa dipantau dari mana saja via MQTT.

> ⚠️ **Penting:** Koneksi WiFi bersifat opsional. Alat tetap bekerja penuh secara offline via BLE.

### Langkah Konfigurasi

1. Pastikan aplikasi sedang **LIVE** (terhubung ke ESP32 via BLE).
2. Masuk ke **Detail Device** → Ketuk ikon ⚙️ pengaturan atau menu Konfigurasi.
3. Masukkan:
   - **SSID** → Nama WiFi (jaringan 2.4GHz, bukan 5GHz)
   - **Password** → Password WiFi
4. Ketuk **Kirim / Simpan**.

### Proses Setelah Dikonfigurasi

```
App kirim CONFIG via BLE
        │
        ▼
ESP32 terima SSID & Password → Simpan ke Memori Permanen (NVS)
        │
        ▼
ESP32 mulai coba konek WiFi (berjalan di latar belakang)
Bluetooth TIDAK terputus selama proses ini ✓
        │
        ▼
Jika berhasil → ESP32 konek ke MQTT Broker otomatis
```

---

## BAB 5 — Menyemprot secara Manual

Gunakan fitur ini untuk menyemprot secara instan kapan saja.

### Langkah Semprot Manual

1. Hubungkan ke perangkat (LIVE via BLE atau Online via MQTT).
2. Dari halaman **Dashboard** atau **Kontrol**, atur durasi menggunakan **slider** (5 – 120 detik).
3. Ketuk tombol **"Mulai Semprot"** / 🟢 **START**.
4. Pompa akan menyala — durasi hitungan mundur akan tampil di layar.
5. Untuk menghentikan lebih awal, ketuk tombol **"Berhenti"** / 🔴 **STOP**.

### Perhitungan Volume

Volume air yang disemprot dihitung otomatis:

```
Volume (ml) = Durasi (detik) × Flow Rate (ml/detik)
Contoh: 30 detik × 15.0 ml/s = 450 ml
```

> Flow Rate disesuaikan dengan nilai kalibrasi yang sudah Anda setting (lihat Bab 8).

---

## BAB 6 — Mengatur Jadwal Otomatis

Jadwal tersimpan langsung di memori ESP32 — alat tetap menyemprot tepat waktu meski HP dimatikan atau Bluetooth tidak aktif.

### Membuat Jadwal Baru

1. Masuk ke **Detail Device** → Tab **Jadwal**.
2. Ketuk tombol **"+ Tambah"** (pojok kanan atas).
3. Isi form yang muncul:
   - **Nama Jadwal** → contoh: "Semprot Pagi"
   - **Jam & Menit** → waktu mulai semprot
   - **Durasi** → geser slider ke durasi yang diinginkan (5–120 detik)
4. Ketuk **Simpan**.
5. Jadwal otomatis terkirim ke ESP32.

### Mengelola Jadwal

| Aksi | Cara |
|------|------|
| ✅ Aktifkan / Nonaktifkan | Geser tombol sakelar di samping jadwal |
| 🗑️ Hapus jadwal | Ketuk ikon tong sampah di samping jadwal |
| 🔄 Sinkronisasi ulang | Ketuk tombol **"Sinkron"** (muncul saat LIVE) |

### Contoh Jadwal yang Disarankan

```
┌──────────────────────────────────────┐
│ Nama          │ Waktu │ Durasi       │
├───────────────┼───────┼──────────────┤
│ Semprot Pagi  │ 07:00 │ 30 detik     │
│ Semprot Siang │ 12:00 │ 20 detik     │
│ Semprot Sore  │ 16:00 │ 30 detik     │
└──────────────────────────────────────┘
```

---

## BAB 7 — Melihat Riwayat Log

Semua aktivitas penyemprotan (manual maupun otomatis) dicatat dan disimpan di HP.

### Cara Melihat Riwayat

1. Masuk ke **Detail Device** → Tab **Riwayat**.
2. Daftar log akan tampil dengan informasi:

| Kolom | Keterangan |
|-------|------------|
| 📅 Tanggal & Jam | Kapan semprot dilakukan |
| ⏱️ Durasi | Berapa detik pompa menyala |
| 💧 Volume | Berapa ml air yang dikeluarkan |
| 🏷️ Mode | Manual / Scheduled (Otomatis) |
| 📡 Metode | BLE atau MQTT |

### Sinkronisasi Otomatis Saat Reconnect

Saat Anda menghubungkan kembali HP ke ESP32, aplikasi otomatis menarik data riwayat terbaru dari alat. Sistem sudah dilengkapi **deduplikasi otomatis** — tidak akan ada entri ganda meskipun Anda sering reconnect.

---

## BAB 8 — Kalibrasi Debit Pompa

Kalibrasi memastikan perhitungan volume air yang disemprot akurat sesuai kondisi pompa Anda.

### Langkah Kalibrasi

Siapkan:
- Gelas ukur / wadah berskala
- Stopwatch (atau gunakan timer bawaan HP)

Prosedur:

```
1. Aktifkan semprot manual selama tepat 10 detik
2. Tampung air yang keluar ke gelas ukur
3. Catat volume air (contoh: 150 ml)
4. Hitung: Flow Rate = Volume ÷ Waktu
           Flow Rate = 150 ml ÷ 10 detik = 15.0 ml/detik
5. Masukkan nilai 15.0 di menu Kalibrasi Alat di aplikasi
6. Kirim/Simpan
```

> **Default Flow Rate:** 15.0 ml/detik

Setelah dikalibrasi, semua laporan riwayat volume akan jauh lebih akurat.

---

## BAB 9 — Fitur Testing Lampu Malam

Lampu malam (LED) secara default menyala otomatis mengikuti jadwal:

```
🌙 Nyala  → 18:00 (Pukul 6 Sore)
☀️ Mati   → 06:00 (Pukul 6 Pagi)
```

Namun untuk keperluan **pengujian/testing**, Anda bisa menyalakan lampu kapan saja tanpa harus menunggu malam.

### Cara Menggunakan Fitur Test

1. Pastikan aplikasi sedang **LIVE** (terhubung ke ESP32).
2. Masuk ke **Detail Device** → Tab **Ringkasan**.
3. Scroll ke bawah — cari opsi **"Test Lampu Malam (Manual)"**.
4. Geser tombol ke **ON** → Lampu langsung menyala.
5. Geser tombol ke **OFF** → Lampu mati, kembali ke mode jadwal otomatis.

> **Catatan:** Saat tombol dalam posisi ON dan Anda disconnect dari ESP32, alat akan tetap dalam posisi lampu menyala hingga Anda kirim perintah OFF, atau ESP32 di-restart.

---

## BAB 10 — Troubleshooting

### ❌ Bluetooth tidak terdeteksi / Scan kosong

| Penyebab | Solusi |
|----------|--------|
| Location Service HP mati | Aktifkan GPS/Location di pengaturan HP |
| Izin lokasi aplikasi ditolak | Buka Pengaturan HP → Aplikasi → Pestzon → Izin → Aktifkan Lokasi |
| ESP32 belum menyala | Pastikan ESP32 mendapat daya |
| Jarak terlalu jauh | Dekatkan HP ke ESP32 (< 5 meter) |

### ❌ Koneksi BLE sering putus

| Penyebab | Solusi |
|----------|--------|
| Gangguan sinyal radio | Jauhkan dari router WiFi atau perangkat elektronik lain |
| Baterai ESP32 lemah | Cek level baterai di dashboard |
| HP dalam mode hemat daya | Nonaktifkan mode hemat daya saat menggunakan aplikasi |

### ❌ Volume air di riwayat menunjukkan 0 ml

| Penyebab | Solusi |
|----------|--------|
| Flow Rate belum dikalibrasi | Masuk ke menu Kalibrasi, isi nilai Flow Rate |
| Nilai kalibrasi 0 | Default-nya 15.0 ml/detik, periksa dan isi kembali |

### ❌ WiFi berhasil dikirim tapi MQTT tidak konek

| Penyebab | Solusi |
|----------|--------|
| SSID/Password salah | Cek ulang penulisan WiFi (case-sensitive) |
| WiFi 5GHz | ESP32 hanya support WiFi **2.4GHz** |
| Broker MQTT tidak bisa dijangkau | Cek koneksi internet router/modem |
| Firewall memblokir port 1883 | Gunakan broker alternatif atau ganti port |

### ❌ Jadwal otomatis tidak berjalan

| Penyebab | Solusi |
|----------|--------|
| Jam ESP32 tidak tersinkron | Hubungkan HP ke ESP32 sekali untuk sync jam |
| Jadwal nonaktif | Cek status sakelar jadwal di tab Jadwal (harus ON) |
| ESP32 tidak bertenaga pada jam tersebut | Pastikan daya tidak terputus |

---

<div align="center">

---

*📖 Manual Book ini disiapkan untuk mendukung penggunaan optimal*
*Pestzon Spray App v1.0.1 bersama ESP32 Smart Sprayer Firmware v2.0*

**© 2026 Ronaltama**
[github.com/Ronaltama/PestzonSprayApps](https://github.com/Ronaltama/PestzonSprayApps)

</div>
]]>
