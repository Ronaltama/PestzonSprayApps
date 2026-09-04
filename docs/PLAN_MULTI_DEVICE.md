# Rencana — Dukungan Banyak Perangkat (Multi-Device ESP)

> Dokumen perencanaan/desain untuk mengubah Alburdat Dashboard dari aplikasi
> **satu-perangkat** menjadi **fleet dashboard multi-device**: app menyimpan
> histori seluruh ESP yang pernah tersambung, menampilkan ringkasan per unit di
> dashboard, membuka detail dari data bertinggal (offline sekalipun), dan dapat
> menyuruh satu / banyak unit menyemprot sekarang atau menerapkan jadwal yang
> sama ke banyak unit.

Dokumen pendamping (tampilan UI) ada di `PLAN_MULTI_DEVICE_UI.md`.

---

## 1. Konteks & Masalah Saat Ini

Arsitektur sekarang diasumsikan **tepat satu perangkat aktif**:

- `BluetoothService` menampung state **tunggal**: `_connectedDevice`,
  `_rxCharacteristic`, `_txCharacteristic`, `_deviceStatus`,
  `_incomingBuffer`, dan empat `StreamController` response. Data perangkat
  kedua yang tersambung akan **menimpa** data pertama (lihat
  `lib/services/bluetooth_service.dart`).
- `DeviceRepository` memilih **satu** kanal aktif (`ble` atau `mqtt`) dan
  mengekspos `summary` / `stats` / `schedules` sebagai nilai tunggal
  terakhir (lihat `lib/services/device_repository.dart`).
- Basis data lokal (`spray_logs`, `spray_schedules`) → **tanpa relasi ke
  device**. Setiap perangkat baru akan `replaceAllSchedules`, jadi jadwal
  "global" ter-overwrite.
- `DashboardPage` menampilkan **satu** hero card + chart yang mengonsumsi
  status global (`deviceRepo.summary`), lihat
  `lib/screens/dashboard_page.dart`.
- Firmware uji `esp32_sh25.ino` memakai **satu service UUID bersama**
  (`4fa1c691-…`) serta nama broadcast `ESP32-SH25` yang sama untuk setiap
  unit, sehingga saat ini mustahil membedakan dua unit.

Konsekuensi: tidak ada "daftar device", data offline per unit hilang dari
dashboard ketika digantikan unit lain, perintah tidak bisa ditargetkan ke
perangkat spesifik, dan tidak ada konsep perintah batch.

## 2. Tujuan (Ruang Lingkup)

1. **Registry perangkat permanen** — setiap ESP yang pernah tersambung
   tercatat dalam SQLite (identitas tetap, nama tampilan, terakhir terlihat),
   sehingga dapat ditampilkan & dijelajahi meski sedang **offline**.
2. **Dashboard multi-kartu** — satu kartu ringkasan per perangkat dengan
   status/telemetri terbaru; hidup kembali bila sedang tersambung (BLE).
3. **Detail per perangkat** — dari data yang **tersimpan** (riwayat semprot,
   jadwal, statistik) + data pull terbaru bila unit tersambung.
4. **Aksi ke satu atau banyak unit** pada perangkat yang tersambung:
   - *Semprot Sekarang* (durasi per unit, atau sama untuk semua),
   - *Terapkan Jadwal yang Sama*,
   - sinkronisasi/pull data.
5. **Identitas unit**: pilihan desain **Opsi 1** — identifikasi via
   **nama & MAC** (`remoteId`) sebagai kunci stabil utama. Persisten bahkan
   ketika masih memakai `serviceUUID` bersama. (Lihat §3.2 untuk peran UUID.)

**Di luar ruang lingkup fase pertama** (dihindari): memegang banyak koneksi
GATT aktif bersamaan, protokol MQTT multi-device, perubahan firmware
perangkat keras nyata (di luar repo uji).

## 3. Keputusan Desain

### 3.1 Identitas & tombol device (device key)

Kunci primer sebuah perangkat adalah **`deviceMac`** (`remoteId.str` dari
`flutter_blue_plus` — alamat BLE, format `xx:xx:xx:xx:xx:xx`), karena:

- selalu unik antar unit di dunia,
- stabil antar sesi (beda dengan nama yang bisa sama / hostname yang dapat
  berubah),
- tersedia tanpa harus terhubung (dari hasil scan).

Representasi penyimpanan `deviceKey` = string MAC (atau fallback
identifier jika MAC kosong). Semua tabel data per-perangkat (log, jadwal,
stats, timestamp sinkron) dikunci oleh `deviceKey` ini, bukan nama.

### 3.2 Peran UUID shared vs per-unit (klarifikasi)

Keputusan final yang kita pakai: **identifikasi via nama+MAC (Opsi 1)**,
dengan tetap memakai service UUID bersama (seperti sekarang firmware uji).
Namun kode tidak mengandalkan UUID untuk *membeda* unit — ia hanya
memfilter apakah sebuah periperal "kompatibel" (memakai service yang
dikenali). Tabel disimpan **mendukung kolom pendukung** `serviceUuid` yang
mengandung UUID yang sedang dipakai perangkat, sehingga:

- nama dan MAC tetap penentu identitas utama,
- bila nanti unit produksi memakai UUID unik, tidak ada migrasi tabel — cukup
  diisi nilai UUID per baris device.

> Pertanyaan terbuka untuk dikonfirmasi bersama firmware produksi: bagaimana
> protokol perintah diterapkan (apakah `cmd` lama `/ JSON envelope baru`),
> lihat §6 — ini hanya mengubah pengiriman, bukan struktur simpanan.

### 3.3 Satu koneksi aktif → sesi pindah (bukan banyak GATT paralel)

Ini **keputusan terpenting** dan berbeda dari pemahaman "parallel scanning":

Baterai & OS mobile tidak ramah untuk menahan banyak koneksi GATT aktif
sekaligus. Untuk mengelola banyak unit, pendekatan yang andal:

```
scan  selang  semua unit (deteksi)      -> daftar siap
konek unit A  -> pull summary/stats      -> catat ts  -> disconnect
konek unit B  -> pull summary/stats      -> catat ts  -> disconnect
...
aksi target:  konek unit(s) tertentu -> kirim perintah -> terima ack -> disconnect
```

Hasil pull kemudian di-**simpan permanen** ke SQLite. Dashboard membaca dari
penyimpanan (histori tersedia offline) & menandai unit tersambung saat ini
dengan badge "Live".

### 3.4 Sinkronisasi data — log & stats permanen per device

Pola sinkron baru:

- **Summary & statistik**: setiap kali unit tersambung, app menarik
  `get_summary` + `get_stats` dan **menyimpan snapshot** ke tabel
  `device_snapshots`.
- **Jadwal**: tidak lagi "global" — disimpan **per `deviceKey`**
  (`spray_schedules.device_key`).
- **Riwayat semprot**: `spray_logs.device_key` ditambahkan; log baru (lokal
  maupun dari ESP) diberi tag unit.
- Grafik batang harian per perangkat dibangun dari `spray_logs` (difilter
  `device_key`) ditambah data snapshot terkini.

## 4. Model Data Baru

Skema (versi DB dinaikkan ke `2`, migrasi berhati-hati; tabel lama diberi
kolom `device_key` bernilai `'default'` untuk data lama agar tidak hilang):

```
esp_devices (
  device_key TEXT PRIMARY KEY,     -- = MAC
  name TEXT NOT NULL,              -- nama broadcast/nama user (editable)
  service_uuid TEXT,               -- UUID GATT integrasi (jika ada)
  ble_advertised_name TEXT,        -- nama asli saat scan (untuk reconnect)
  last_seen_at TEXT,               -- last pull/connect
  last_battery INTEGER,
  last_volume_ml REAL,
  is_favorite INTEGER DEFAULT 0,
  created_at TEXT
)

spray_logs        ... + device_key TEXT
spray_schedules   ... + device_key TEXT

device_snapshots (
  id INTEGER PK,
  device_key TEXT,
  captured_at TEXT,
  payload TEXT,       -- JSON dari get_summary/get_stats untuk riwayat historis
)
```

Relasi log & schedule tersedia per unit untuk detail. `device_snapshots`
memberi histori kapan snapshot diambil untuk perbandingan waktu.

## 5. Rencana Implementasi (Back-End / Layanan)

### Fase A — Fondasi data & identitas
1. Buat model `EspDevice` + migrasi DB (`DatabaseHelper` v2);
   tabel baru + kolom `device_key`; metode CRUD.
2. `EspDeviceRegistry` (service / ChangeNotifier): daftar semua unit dari DB,
   `upsertFromScan`, `markConnected`, dsb.

### Fase B — `BluetoothService` multi-sesi
3. Ganti state global menjadi **satu sesi aktif saat ini** yang membawa
   `deviceKey`. Tetap hanya satu sambungan fisik pada suatu waktu.
4. Tambah pipeline keperangkat:
   `connectToDeviceKey(key)` → resolve device (dari hasil scan/system dev)
   → auto-register device di registry saat pertama ketemu.
5. Refactor inbound buffer & response sehingga terikat ke sesi yang sedang
   berjalan; tidak ada campuran antar unit.
6. Tambah perintah bantuan publik:
   `sprayNow(duration)`, `pushSchedules(...)` (tetap, kini untuk sesi aktif).
7. Public event `DeviceCommandAck` / callback agar pemanggil tahu perintah
   satu unit selesai (sukses/gagal) — dasar untuk loop batch.

### Fase C — `DeviceRepository` menjadi per-key
8. Tampilkan `devices` (registry), bukan `summary` tunggal.
9. Tambah API per-key: `refreshDeviceSummary(mac)`, `pullSchedules(mac)`,
   dsb — internal: pastikan kanal = `ble` untuk key itu (jika hanya ble).
10. Simpan hasil pull ke DB (`EspDeviceRegistry`/snapshot).
11. `summary` global lama dipertahankan untuk kompatibilitas layar skema lama
    (dipakai halaman jadwal/riwayat sementara), sampai layar itu dipindahkan.

### Fase D — Aksi batch (semprot sekarang / jadwal bersama)
12. `MultiDeviceOperator` / metode pada repository: urutan sesi per unit,
    tiap langkah konek → kirim → ack → disconnect; kumpulkan laporan
    `{deviceKey: hasil}`. Aman untuk klik cepat (serial/berurutan).

## 6. Pertanyaan yang Perlu Diklarifikasi (bersama pemilik firmware/produk)

1. **Protokol di unit produksi**: pakai `cmd` lama
   (`{cmd:'START', ...}`) atau kontrak *envelope* (`{v,t}`) + framing? Ini
   menentukan `_sendBleMessage` vs `_sendBleEnvelope` saat aksi.
2. **Perintah batch** *Semprot Sekarang*: apakah firmware mengaktifkan pompa
   langsung, atau ada penyetujuan/state "ready"? (menentukan waktu & status ack)
3. **Sinking time** per unit: jumlah unit maksimum nyata yang perlu
   ditarik per siklus dashboard (budget koneksi ≤ 2–3 dtk/unit).
4. Apakah perlu **jadwal default awal** per device baru (seed) atau hanya
   dari pull ESP? (Menentukan isi `spray_schedules` saat device pertama
   dikenal).
5. UUID & identitas produksi final: tetap nama+MAC dengan UUID shared (Opsi
   1) atau nambah variable per-unit? — keputusan per firmware/produksi.

## 7. Urutan Kerja yang Disarankan (ringkas)

1. DB + model `EspDevice` + registry (Fase A).
2. Refactor BLE jadi sesi tunggal-per-device (Fase B) — tetap kompatibel
dengan layar lama.
3. Dashboard membaca registry / per-`deviceKey` (lihat rencana tampilan di
`PLAN_MULTI_DEVICE_UI.md`).
4. Layar "Perangkat" me-list seluruh unit registry + aksi batch (Fase D).
5. Setelah BLE teruji, pindahkan/modernkan kanal MQTT lama menjadi opsional
per device (atau hapus kontrak single-device).
