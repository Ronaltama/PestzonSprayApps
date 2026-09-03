# Implementation Plan: Fitur Baca/Tulis Data ESP (Device Sync)

## Overview

Menjadikan ESP32 sebagai **sumber kebenaran** untuk data operasional alat semprot (kesimpulan hari ini, statistik volume 7 hari, dan jadwal semprot) dengan menambahkan mekanisme *request/response* di atas kanal BLE dan MQTT yang sudah ada. Aplikasi menarik data dari ESP saat terhubung, menampilkannya di dashboard & halaman jadwal, dan setiap perubahan jadwal langsung ditulis balik ke ESP.

Lingkup pekerjaan (sesuai kesepakatan):
1. **Kesimpulan hari ini** (total volume, total sesi, baterai, debit) → card kesimpulan paling atas dashboard. ✅ dikerjakan
2. **Statistik volume per hari (7 hari)** tersimpan di perangkat → card Statistik Volume. ✅ dikerjaan
3. **Baterai** → card Sistem Daya Kebun. ✅ dikerjakan (data menyatu di `summary`)
4. Pompa misting DC. ⏭️ di-skip
5. **Jadwal semprot**: baca dari ESP + tulis (tambah/hapus/nyalakan/matikan) langsung auto-sync ke ESP. ✅ dikerjakan
6. Riwayat semprot hari itu. ⏭️ di-skip

Keputusan dari pemilik produk:
- Kontrak JSON belum ada → **dirancang di dokumen ini**.
- Kanal: rekomendasi disetujui = **BLE & MQTT dua-duanya** via satu kontrak + lapisan repositori.
- Statistik disimpan ESP: **7 hari** (berbasis tanggal kalender).
- Jadwal: saat connect app **menarik jadwal dari ESP**, setiap perubahan lokal **langsung auto-kirim**; cukup **1 perangkat**.
- Debit pompa: **nilai default** (`5.0 ml/s`, tetap konstanta di app, tidak dibaca dari ESP).

## Architecture Decisions

1. **Kontrak JSON tunggal, transport-agnostic** — Satu format *envelope* `{"v":1,"t":"<type>",...}` dipakai identik di MQTT dan BLE. Request & response memakai `t` yang sama. Firmware cukup menangani satu format.
2. **ESP = sumber kebenaran** untuk: counter hari ini, statistik 7 hari, dan daftar jadwal. SQLite lokal berubah peran menjadi **cache/fallback offline** + riwayat log manual. Saat ESP offline, dashboard menampilkan data cache/estimasi terakhir + label "offline".
3. **Summary MQTT gratis** — Topik push `sprayer/{id}/status` sudah membawa field yang sama dengan `summary`. Untuk MQTT, `summary` cukup disusun dari status push terbaru; `get_summary` hanya fallback saat perlu refresh eksplisit. Untuk BLE, summary selalu via request/response.
4. **BLE framing: newline-delimited JSON** — Setiap pesan diakhiri `\n`. Receiver buffer sampai menemukan `\n`, sehingga pesan yang terpecah-pecah karena MTU tetap utuh tanpa protokol chunking.
5. **MQTT topik baru** — `sprayer/{id}/request` (App→ESP) dan `sprayer/{id}/response` (ESP→App). Topik `status`, `log`, `command`, `config` tetap dipertahankan untuk kompatibilitas push & kontrol.
6. **Jadwal = full-list replace** — ESP menyimpan satu daftar jadwal utuh (di NVS). Setiap aksi lokal (tambah/hapus/toggle) → app mengirim daftar penuh `set_schedules`. Lebih sedikit state, idempoten, dan tidak ada masalah sinkronisasi id antar DB lokal ↔ ESP.
7. **Pull jadwal saat connect menimpa DB lokal** — id pada DB lokal mengikuti id dari ESP supaya referensi stabil. Skenario ESP kosong saat *first run*: app mengirim seed bawaan (Semprot Pagi/Sore) satu kali, setelah itu ESP kosong = daftar kosong dihormati.
8. **Kunci summary kompatibel `DeviceStatus.fromJson`** — `battery`, `voltage`, `isSolar`, `isPumpRunning`, `totalSesi`, `totalVolume` → parser lama dipakai ulang; `connState` diisi dari kanal aktif.
9. **7 hari berbasis tanggal** — ESP menyimpan volume/sesi per tanggal kalender. App meminta rentang pekan berjalan (`from`=Senin s.d. `to`=Minggu); ESP membalas tanggal yang tersedia (hari lalu & hari ini). App memetakan ke kolom Sen–Min (hari belum lewat = 0).
10. **Debit pompa tetap konstanta** — `5.0 ml/s` di app; tidak ditambahkan ke kontrak.

## Kontrak JSON

### Envelope

Semua pesan adalah satu objek JSON:

```jsonc
{ "v": 1, "t": "<type>", ...data }
```

`v` = versi kontrak (integer). Pesan dengan `v` tidak dikenal → diabaikan + log.

### Tabel tipe

| `t` (req) | `t` (resp) | Trigger | Payload request | Payload response |
|---|---|---|---|---|
| `get_summary` | `summary` | App minta refresh kesimpulan hari ini | — | Lihat contoh |
| `get_stats` | `stats` | App minta statistik pekan berjalan | `from` (YYYY-MM-DD), `to` (YYYY-MM-DD) | `days[]` |
| `get_schedules` | `schedules` | App menarik jadwal dari ESP | — | `schedules[]` |
| `set_schedules` | `ack` | App menulis daftar jadwal penuh | `schedules[]` | `ok`, `ref` |

### Contoh payload

```jsonc
// 1. Request summary → Response summary
{ "v":1, "t":"get_summary" }
→ { "v":1, "t":"summary",
    "battery": 87,             // persen 0..100
    "voltage": 4.12,           // volt baterai
    "isSolar": 1,              // 0/1
    "isPumpRunning": 0,        // 0/1
    "totalVolume": 1234.5,     // ml, total HARI INI
    "totalSesi": 6,            // jumlah sesi HARI INI
    "ts": 1756900000 }         // unix detik (waktu ESP)

// 2. Request stats (pekan berjalan) → Response stats
{ "v":1, "t":"get_stats", "from":"2026-08-31", "to":"2026-09-06" }
→ { "v":1, "t":"stats",
    "days": [
      { "d":"2026-08-31", "v": 900.0, "s": 4 },   // d = YYYY-MM-DD
      { "d":"2026-09-01", "v": 1200.0, "s": 6 },
      ... // hanya tanggal yang tersedia & sudah lewat; terurut menaik
    ] }

// 3. Request jadwal → Response jadwal
{ "v":1, "t":"get_schedules" }
→ { "v":1, "t":"schedules",
    "schedules": [
      { "id": 1, "title": "Semprot Pagi", "hour": 7, "minute": 0, "duration": 30, "active": 1 },
      { "id": 2, "title": "Semprot Sore", "hour": 16, "minute": 0, "duration": 30, "active": 1 }
    ] }

// 4. Tulis jadwal (penuh) → ACK
{ "v":1, "t":"set_schedules", "schedules": [ ...daftar utuh... ] }
→ { "v":1, "t":"ack", "ref": "set_schedules", "ok": 1 }
// ok = 1 sukses, 0 gagal (opsional "err": "pesan singkat")
```

### MQTT topics (update)

| Topic | Arah | Isi |
|---|---|---|
| `sprayer/{id}/status` | ESP → App | Push status berkala (tetap, ~`summary` tanpa `ts`) |
| `sprayer/{id}/log` | ESP → App | Log/riwayat semprot (tetap) |
| `sprayer/{id}/command` | App → ESP | Kontrol (tetap: `spray`, `stop`, dll) |
| `sprayer/{id}/config` | App → ESP | Config WiFi (tetap) |
| `sprayer/{id}/request` | App → ESP | **Baru**: envelope request (`get_summary`, `get_stats`, `get_schedules`, `set_schedules`) |
| `sprayer/{id}/response` | ESP → App | **Baru**: envelope response (`summary`, `stats`, `schedules`, `ack`) |

> Transisi: `sync_schedules` (via `/config`) & `cmd: SCHEDULE` (BLE) adalah format lama. Kontrak baru menggantikannya; format lama boleh dipertahankan firmware untuk sementara, app beralih penuh ke format baru.

### BLE framing (update)

- Sama seperti sekarang: app menulis JSON ke karakteristik RX (write), ESP membalas via karakteristik TX (notify).
- **Baru**: setiap pesan TX diakhiri karakter `\n` (newline-delimited). App menyimpan byte masuk ke buffer dan memproses per baris; pecahan antar-notifikasi (batas MTU) digabung otomatis.
- Request app → ESP juga diakhiri `\n` agar konsisten di sisi firmware.
- Payload yang melewati MTU boleh dipecah firmware asal tetap satu baris utuh yang diakhiri `\n`.

## Task List

### Phase 0: Fondasi kontrak & model
- [ ] **Task 1**: Tambah model `DailyVolumeStat` (`lib/models/daily_volume_stat.dart`) + parser/mapper dari `t: stats` dan helper tanggal → index hari Sen–Min. Unit test parse JSON.
- [ ] **Task 2**: `MqttService` — subscribe `sprayer/{id}/response`; parse envelope; ekspos stream hasil (`summaryStream`, `statsStream`, `schedulesStream`, `ackStream`) + method request (`requestSummary`, `requestStats(from,to)`, `requestSchedules`, `pushSchedules` pakai `set_schedules`); tambah timeout/retry sederhana; pertahankan parse `status`/`log` lama.
- [ ] **Task 3**: `BluetoothService` — refactor `_handleIncomingData` jadi buffer newline; parse envelope `t`; ekspos stream hasil yang sama; method request yang sama via RX; format BLE lama (`battery/solar/pump` pendek) tetap ditoleransi selama transisi.

### Checkpoint: Fondasi
- [ ] `flutter analyze` bersih
- [ ] Unit test parser envelope & `DailyVolumeStat` lolos
- [ ] Uji manual terima response tiruan (MQTT publish / BLE notify) → stream keluar benar

### Phase 1: Repository + Kesimpulan hari ini & Sistem Daya (Item 1 & 3)
- [ ] **Task 4**: `DeviceRepository extends ChangeNotifier` (`lib/services/device_repository.dart`) — pilih kanal aktif (BLE dulu, fallback MQTT), expose `summary`, `stats`, `schedules`, `isRefreshing`, method `refreshAll()`, `refreshSummary()`, `refreshStats()`, `pullSchedules()`, `pushSchedules()`; auto-refresh saat status koneksi berubah; daftarkan di `main.dart`.
- [ ] **Task 5**: Dashboard — Hero Day Card & Sistem Daya Kebun membaca `DeviceRepository.summary` (bukan estimasi lokal). Hapus dummy `battery:90/voltage:4.15` saat connect BLE; tambah tombol/indikator refresh; hentikan increment `totalSesiToday`/`totalVolumeTodayMl` lokal di `BluetoothService.startSpraying` (counter ESP yang dipakai; setelah semprot selesai → `refreshSummary()`).

### Checkpoint: Summary & Daya
- [ ] Card kesimpulan menampilkan data ESP (volume, sesi, baterai) dan berubah setelah ESP merespons
- [ ] Sistem Daya Kebun tidak lagi menampilkan nilai dummy saat connect BLE

### Phase 2: Statistik Volume 7 hari (Item 2)
- [ ] **Task 6**: Dashboard `_buildStatisticChartCard` — sumber data dari `DeviceRepository.stats` (7 hari pekan berjalan, mapping ke kolom Sen–Min; hari belum lewat = 0); fallback ke hitungan SQLite lama saat offline; subtitle total minggu & tooltip ikut data baru.

### Checkpoint: Statistik
- [ ] Bar chart merefleksikan data ESP (tanggal & nilai)
- [ ] Saat ESP offline, chart tetap tampil dari fallback SQLite + indikator stale

### Phase 3: Jadwal Semprot baca + tulis (Item 5)
- [ ] **Task 7**: `SchedulePage` jadi stateful; saat kanal aktif baru terhubung (listener `DeviceRepository`) → `pullSchedules()` lalu timpa DB lokal (id mengikuti ESP); seed bawaan hanya dikirim sekali saat ESP kosong & belum pernah sync.
- [ ] **Task 8**: Auto push `pushSchedules()` setelah setiap aksi: tambah jadwal (dialog), toggle nyalakan/matikan, hapus. Tombol sync manual dipertahankan sebagai "kirim ulang" cadangan. Tampilkan notifikasi sukses/gagal (timeout/offline).

### Checkpoint: Jadwal
- [ ] Connect → daftar ESP tampil di halaman jadwal (DB lokal tertimpa)
- [ ] Tambah/hapus/toggle → daftar terkirim ke ESP & tersimpan setelah ESP restart (NVS)

### Phase 4: Polish & dokumentasi
- [ ] **Task 9**: Notifikasi & state error (timeout request, ESP offline, `ack ok:0`); indikator "sync" di halaman jadwal; hapus tombol/teks yang usang.
- [ ] **Task 10**: Update `docs/API_REFERENCE.md` & `docs/ARCHITECTURE.md` (topik baru, kontrak, alur request/response, catatan firmware).

### Checkpoint: Selesai
- [ ] `flutter analyze` bersih, seluruh unit test lolos
- [ ] Skenario end-to-end: connect (BLE & MQTT) → pull → ubah jadwal → restart ESP → data tersimpan
- [ ] Plan direview & disetujui sebelum implementasi penuh

## Catatan untuk Firmware ESP32 (di luar repo ini)

- Simpan di NVS/EEPROM (atau Preferences): (a) daftar jadwal (`id`, `title`, `hour`, `minute`, `duration`, `active`), (b) statistik 7 hari keyed tanggal, (c) counter total volume & sesi hari ini (dengan reset otomatis saat tanggal berganti).
- Sediakan RTC/waktu valid (NTP) — statistik & reset harian bergantung tanggal.
- Subscribe MQTT `sprayer/{id}/request`; publish response ke `sprayer/{id}/response`. Untuk BLE: balas via notify TX diakhiri `\n`.
- Pertimbangkan *wear-leveling* NVS: tulis jadwal pakai commit tunggal per `set_schedules` (bukan per item), dan tulis statistik harian maks. beberapa kali/hari.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Firmware belum punya request/response & NVS stats | High | Kontrak di dokumen ini jadi acuan; kerja paralel app & firmware; format lama tetap jalan sampai firmware rilis |
| Waktu ESP tidak akurat → statistik & reset harian salah tanggal | High | Wajib NTP/RTC valid; app menampilkan tanggal dari ESP di tooltip; fallback offline jika tanggal ESP jauh dari tanggal HP |
| Payload BLE melebihi MTU | Med | Newline framing membuat pecahan aman; pesan dibuat ringkas; ESP disarankan negosiasi MTU ≥ 185 |
| Response hilang/terlambat (BLE jauh / MQTT putus) | Med | Timeout + retry di repository; UI tetap pakai cache + label offline/stale |
| Konflik id jadwal DB lokal vs ESP | Med | Full-list replace & id mengikuti ESP; DB lokal hanya cache |
| NVS wear akibat auto-push tiap toggle | Low | Commit tunggal per operasi di firmware; frekuensi perubahan jadwal rendah |

## Open Questions (opsional, tidak memblokir)

- Apakah firmware punya seed jadwal bawaan sendiri saat NVS kosong? (Menentukan perilaku first-run; default plan: app seed satu kali lalu hormati ESP.)
- Perlu mendukung pergantian `deviceId` MQTT (multi-perangkat) nanti? Di luar lingkup sekarang.
