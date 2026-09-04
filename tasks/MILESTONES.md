# Milestones — Eksekusi Bertahap Multi-Device ESP

> Roadmap eksekusi bertahap untuk mengubah aplikasi dari **single-device**
> menjadi **fleet dashboard multi-device**. Sumber desain: `../docs/PLAN_MULTI_DEVICE.md`
> (arsitektur/data) & `../docs/PLAN_MULTI_DEVICE_UI.md` (tampilan).
>
> Konvensi tiap milestone:
> - **Item** adalah unit kerja yang bisa dipisahkan; centang saat selesai.
> - **Definisi selesai (DoD)** = kriteria penerimaan untuk menutup milestone.
> - Sebuah milestone **hanya ditutup setelah DoD terpenuhi**; kerjakan urut.
> - `flutter analyze` & unit test harus bersih di akhir tiap milestone.

---

## Ringkasan Milestone

| # | Milestone | Fokus | Hasil yang dapat dilihat/dirasa |
|---|---|---|---|
| M0 | Identitas & registry device | Model `EspDevice`, migrasi DB, registry service | Device tersimpan permanen, list registry dasar |
| M1 | Sesi BLE satu device per-key | Refactor `BluetoothService` sesi tunggal berkey MAC | Koneksi bertahan; state terisolasi per perangkat aktif |
| M2 | Repository per-perangkat + penyimpanan data | Simpan snapshot, jadwal & log `device_key` | Dashboard membaca per perangkat; histori abadi tersimpan |
| M3 | Dashboard fleet (multi kartu) | DeviceCard fleet + aksi per kartu | Dashboard menampilkan SEMUA unit tersimpan |
| M4 | Detail per unit | Layar detail unit (summary, stats, jadwal, riwayat) | Kartu ringkasan → detail penuh per unit, offline pun terbaca |
| M5 | Registry UI + Pindai & Tambah | Tab “Perangkat”: list registry + tambah dari scan | Kelola daftar unit (tambah/hapus/pilih favorit) |
| M6 | Aksi batch & jadwal bersama | Batch semprot sekarang + terapkan jadwal ke banyak | “Semprot sekarang” ke 1–banyak unit; hasil per unit |

> M0–M2 = fondasi data/BLE; M3–M6 = tampilan & aksi. UI dibuat membaca data
dari DB, jadi sebuah milestone dapat ditutup meski banyak unit sedang offline.

---

## M0 — Identitas & Registry Device (fondasi data)

**Goal:** memperkenalkan identitas stabil (`device_key` = MAC) dan
penyimpanan permanen daftar perangkat.

### Item
- [x] **M0.1** Model `EspDevice` (`lib/models/esp_device.dart`) + mapper
      JSON/SQLite.
- [x] **M0.2** Migrasi `DatabaseHelper` v1→v2:
      buat tabel `esp_devices`; tambah kolom `device_key` pada `spray_logs` &
      `spray_schedules` (default `'default'` untuk data lama); versi & onUpgrade.
- [x] **M0.3** CRUD registry di `DatabaseHelper` (`upsertDevice`,
      `getAllRegisteredDevices`, `updateName`, `markLastSeen`, `deleteDevice`
      serta hapus data yang terikat pada unit).
- [x] **M0.4** Service `EspDeviceRegistry` (ChangeNotifier) memuat semua unit
      dari DB, `upsertFromDeviceKey(...)`, ekspos `devices` + event.

### Catatan
- Sudah dibuat: `lib/models/esp_device.dart`, `lib/services/esp_device_registry.dart`,
  migrasi skema v2 + CRUD di `lib/services/database_helper.dart` (mode in-memory
  saat FLUTTER_TEST), dan unit test `test/models/esp_device_test.dart` +
  `test/services/esp_device_registry_test.dart`.

### Definisi Selesai (M0)
- [x] `flutter analyze` & test bersih.
- [x] Buka app: tak ada error migrasi; tabel `esp_devices` ada (diuji via use
      db di mode test).
- [x] `DatabaseHelper` dapat menyimpan & membaca kembali daftar unit
      (diverifikasi lewat unit test registry).

---

## M1 — Sesi BLE satu-perangkat berpindah (bukan GATT paralel)

**Goal:** `BluetoothService` memakai **satu sesi aktif ber-key** sehingga state
& buffer masuk terikat pada satu `device_key` saat connect/disconnect.

### Item
- [x] **M1.1** `BluetoothService` mengganti state global menjadi **sesi aktif
      ber-key**: tambah `_activeDeviceKey` (=`remoteId.str`) + getter
      `activeDeviceKey`; getter lama (`isConnected`, `connectedDeviceName`,
      `deviceStatus`) tetap dipertahankan untuk kompatibilitas UI.
- [x] **M1.2** Isolasi inbound per sesi: buffer newline tetap tunggal tapi
      di-reset bersih saat connect & disconnect sehingga tidak mencampur
      antar unit (dua perangkat berpindah tdk saling menimpa telemetri).
- [x] **M1.3** Tambah pendukung keyed connect: mencatat `activeDeviceKey` saat
      connect sukses; reset saat memulai connect berikutnya & saat disconnect.
      (Registrasi otomatis ke `EspDeviceRegistry` ditunda ke M2 karena registry
      belum di-provide & akan diakses repository.)
- [x] **M1.4** Sinkronisasi sumber: lapisan pemakai (M2) menautkan response ke
      perangkat lewat `activeDeviceKey` saat event tiba (desain dipilih supaya
      stream event & UI lama tak berubah API-nya di M1).

### Catatan
- Kendala teknis: pengujian koneksi dua perangkat BLE membutuhkan perangkat
  keras; isolasi divalidasi lewat `flutter analyze` + seluruh suite test, dan
  memerlukan uji fisik ringkas oleh pengembang.

### Definisi Selesai (M1)
- [x] Connecting/disconnecting device berurutan tidak menimbulkan state
      silang (reset `_deviceStatus` bila key berubah; cleared saat disconnect)
      — validasi via analisis + perlu uji fisik ringkas di perangkat.
- [x] Regresi: UI lama (Dashboard/BLE) masih berfungsi — `flutter analyze`
      bersih; 26 test lulus.

---

## M2 — Repository per-perangkat + Simpan Data Permanen

**Goal:** `DeviceRepository` jadi per-`device_key`; hasil pull disimpan
permanen sehingga histori terlihat tanpa harus terhubung.

### Item
- [x] **M2.1** `DeviceRepository` menyimpan status per `device_key`
      (`Map<String, DeviceStatus>` + `statusOf(key)` / `loadLastSnapshot(key)`)
      selain `summary` lama.
- [x] **M2.2** Snapshot persisten: tabel `device_snapshots` (skema v3) +
      metode simpan/baca terbaru (`saveDeviceSnapshot`,
      `latestDeviceSnapshot`); `summary` yang diterima pada sesi BLE aktif
      ikut disimpan saat event masuk.
- [x] **M2.3** `spray_logs` diisi `device_key` dari sesi BLE aktif
      (`SprayLog.deviceKey` baru; jalur manual BLE memakainya; fallback
      `'default'` utk legacy). `spray_schedules` tetap global sementara.
- [ ] **M2.4** Jadwal per-`device_key` di pindah ke M4 (menyentuh layar
      Schedule utk memilih unit utama; diselesaikan bersama Detail/UI). → M4
- [x] **M2.5** Auto-refresh saat sesi (M1) terhubung menyalurkan summary ke
      cache per-key & snapshot DB.

### Catatan
- Registrasi last-seen di `esp_devices` (metadata MAC) disambungkan saat M3
  (lapisan UI membaca registry); penyimpanan snapshot per sesi kini sudah
  berfungsi.
- Jadwal global dipertahankan sampai M4 supaya detail/schedule tak dirombak
dua kali.

### Definisi Selesai (M2)
- [x] Connect unit (BLE manual/refresh) → summary tersimpan ke DB snapshot;
  log manual diberi `device_key` pemiliknya.
- [x] Logika pull & simpan berjalan tanpa memutus sisi layar lama —
  `flutter analyze` bersih; seluruh suite test lulus (29).

> Item M2.4 (jadwal per-device) **sengaja didefer ke M4** agar perubahan layar
> Schedule dilakukan sekali pada fase UI. M2 ditutup untuk bagian penyimpanan
> data; jadwal per-key sepenuhnya dituntaskan di M4.

---

## M3 — Dashboard Fleet (banyak kartu unit)

**Goal:** mengganti asumsi satu-device pada Dashboard dengan grid/list kartu
per unit tersimpan; kartu hidup bila sedang terhubung, tetap jalan dari snapshot.

### Item
- [x] **M3.1** Widget `DeviceCard` baru (`lib/widgets/device_card.dart`):
      identitas + ringkasan snapshot persisten + chip Live + aksi
      Detail / Semprot.
- [x] **M3.2** `DashboardPage` menampilkan daftar kartu seluruh
      `EspDeviceRegistry.devices` di atas + header armada ringkas ketika ada
      perangkat tersimpan (diprovide di `main.dart` + reload saat start).
- [ ] **M3.3** Kartu mengarah ke Detail Unit — *placeholder tersedia*:
      tombol Detail kini memberi infomasi “tersedia di M4”. Menunggu M4 utk
      berlayar ke Detail nyata.
- [ ] **M3.4** Tombol refresh per-kartu eksplisit menyusul; daftar otomatis
      terbawa via perubahan registry (reload). Label “terakhir …” sebagian
      via snapshot card. Disempurnakan dengan M4/detail.
- [x] **M3.5** Kosong: saat tak ada device, dashboard kembali/terus ke tampilan
      tunggal legacy. (Pemandu “Pindai Perangkat Pertama” ditangani tab
      Perangkat M5.)

### Catatan
- Saat device tersimpan, dashboard utama menampilkan armada kartu; konten
  tunggal (hero/chart/solar/pump) kini hanya dipakai pada kondisi “belum ada
  perangkat tersimpan”. Perangkat yang tak tertutup ui detail dirapikan pada
  M4.

### Definisi Selesai (M3)
- [x] Dashboard menampilkan banyak kartu (registry) bila tersedia; kartu
      memakai snapshot DB per unit (Data tampil offline).
- [ ] Membuka app tanpa koneksi → kartu tetap tampil dari snapshot perlu
      verifikasi visual dengan perangkat/registry terisi (rasa uji fisik).
- [x] `flutter analyze` bersih & seluruh suite test (32) lulus.

---

## M4 — Detail Per Unit

**Goal:** buka Detail satu unit berisi Ringkasan / Statistik / Jadwal / Riwayat /
Koneksi (per UI §3.2) dari data tersimpan + pull bila live.

### Item
- [ ] **M4.1** Layar `DeviceDetailScreen(mac)` (dibuka dari kartu di M3).
- [ ] **M4.2** Bagian Ringkasan (ml hari ini & minggu, sesi, baterai,
      tegangan, isSolar) dari snapshot/status.
- [ ] **M4.3** Bagian Statistik — grafik batang volume harian per unit
      (widget chart yang ada dipakai ulang).
- [ ] **M4.4** Bagian Jadwal — daftar `spray_schedules` untuk unit tsb + toggle.
- [ ] **M4.5** Bagian Riwayat — `spray_logs` difilter per `device_key`.
- [ ] **M4.6** Aksi: Sinkron (pull saat live) & Edit nama (registry); titik
      masuk ke aksi batch (M6).

### Catatan
- Bagian Koneksi (scan + SSID/WiFi config per unit) boleh masuk M5 bila layar
  config tetap per-unit; kecuali blocker.

### Definisi Selesai (M4)
- [ ] Dari kartu → Detail unit menampilkan data tersimpan; offline tetap penuh.
- [ ] Saat unit tersambung & user refresh → angka terbaru masuk detail.

---

## M5 — Registry UI & “Pindai & Tambah”

**Goal:** Tab Perangkat menjadi registry (daftar semua unit + manajemen)
dan tempat memasukkan unit baru dari hasil scan.

### Item
- [ ] **M5.1** Tab Perangkat (kini menggantikan `BluetoothPage`) menampilkan
dua bagian: registry (atas) & pemindai (bawah) sesuai UI §3.3.
- [ ] **M5.2** Registry: daftar unit lengkap (nama/MAC), ikon favorit, hapus
unit (dengan konfirmasi ikut-hapus data).
- [ ] **M5.3** “Pindai”: umpan hasil scan + centang pilih-ganda; tombol
“Tambahkan (n) unit” → registry; yang sudah dikenal ditandai “Sudah ada”.
- [ ] **M5.4** Arah koneksi tetap satu-perangkat: unit terpilih pada satu baris
(connect → detail); sesi BLE satu-perangkat (M1) dipertahankan.

### Catatan
- Perangkat ter-register tetap tampil di dashboard meski saat ini belum dapat
diedit nama/SSID dari sini; pengelolaan config menjadi tugas lanjutan bila
diperlukan (mis. di layar Detail unit).

### Definisi Selesai (M5)
- [ ] Dari hasil scan dapat menambah 1–banyak unit baru ke registry.
- [ ] Nama/mac & aksi tampil di tab Perangkat; hapus berfungsi (ikut pilihan data).

---

## M6 — Aksi Batch & Jadwal Bersama

**Goal:** mengirim *Semprot Sekarang* ke satu/banyak unit, dan menetapkan jadwal
yang sama ke beberapa ESP (UI §4).

### Item
- [ ] **M6.1** `MultiDeviceOperator` (metode di repo M5/M6): pemroses berurutan
      konek → kirim → ack → disconnect; hasil `{deviceKey: ok|gagal|offline}`.
- [ ] **M6.2** Dialog durasi semprot (dibuka dari kartu/Detail) — termasuk
      cara mode batch diaktifkan lewat tombol “Aksi Batch” di Dashboard.
- [ ] **M6.3** `BatchProgressDialog`: menampilkan progress per unit + hasil akhir.
- [ ] **M6.4** “Terapkan Jadwal Sama ke Unit Lain…” pada pengelola jadwal
      (M4) → pilih unit → jalankan batch jadwal.
- [ ] **M6.5** Menangani unit yang offline saat batch berjalan (lewatkan +
laporkan di ringkasan akhir).

### Definisi Selesai (M6)
- [ ] Semprot sekarang diteruskan ke 1 & banyak unit (yang dapat dijangkau);
      hasil per unit ditampilkan.
- [ ] Terapkan jadwal bersama dieksekusi berurutan tanpa ACK “nyilih”.
- [ ] “flutter analyze” bersih; end-to-end hanya memakai satu/multi BLE → aksi.

---

## Risiko & Penangguhan

| Risiko | Mitigasi |
|---|---|
| Skala perubahan besar di M3–M5; banyak layar dipakai sementara | Kerjakan berurutan; UI dashboard lama disimpan sampai M6 selesai, baru dibersihkan |
| Firmware hanya melayani 1 GATT pada satu waktu → batch perlu serial connect | Operator berurutan (M1/M6); tiap unit di-pull & disconnect; bukan parallel GATT |
| Migrasi kolom `device_key` untuk data lama | Kolom di-update sekali saat migrasi; `'default'` tetap valid sebagai “unit lama” |
| Perombakan `DeviceRepository` | `summary` lama dipertahankan sebagai lapisan kompatibilitas hingga M4 |
| Status “live” berubah saat connect antar unit untuk batch | Label offline/snapshot lewat DB menangkal kesan semua unit hidup |

---

## Cara pakai

1. Tutup M0 → M1 → … secara berurutan; buat PR/buat perubahan per milestone.
2. Centang item di dokumen per milestone & tandai “DoD ✓” saat penerimaan
   sesuai daftar di atas.
3. Setelah tiap DoD, jalankan `flutter analyze` + unit test → bersih.
4. Rujuk `../docs/PLAN_MULTI_DEVICE.md` dan `../docs/PLAN_MULTI_DEVICE_UI.md`
   bila butuh detail arsitektur/tampilan.
