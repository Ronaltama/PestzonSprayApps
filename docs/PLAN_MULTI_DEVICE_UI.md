# Rencana Tampilan (UI) — Dashboard Multi-Device

Dokumen ini fokus hanya pada **pengalaman layar** untuk mendukung banyak
perangkat: struktur layar, alur navigasi, dan komponen interaksi. Mengikuti
palet & gaya yang ada di aplikasi (dark-first, `greenAccentColor #D5FF40`
sebagai aksen, kartu rounded 20–28, font `Utendo`).

Impelementasi data & layanan ada di `PLAN_MULTI_DEVICE.md` (referensi skema,
registry, batch operation).

---

## 1. Prinsip UI

1. **Histori abadi** — data dari perangkat yang dulu pernah tersambung
   tetap terlihat. Setiap kartu mewakili *satu unit* yang tersimpan di
   registry, bukan perangkat yang sedang discan.
2. **Live vs tersimpan jelas** — unit yang sedang terkoneksi BLE ditandai
   badge "Live"; yang lain menampilkan snapshot tersimpan (mungkin agak
   usang). Nyatakan kapan terakhir tersambung ("terakhir: 2 jam lalu").
3. **Seragam tetapi mudah dibedakan** — interaksi per unit konsisten supaya
daftar banyak perangkat tidak membingungkan.

Palet yang dipakai (dari tema saat ini):
- Latar: `darkBgColor` (gelap) / putih (terang);
- Kartu: `darkCardColor` (gelap) / putih;
- Aksan hijau-neon `greenAccentColor` untuk aksi utama & sorotan;
- Status lampu: hijau terang = live, kuning/abu = offline/berkala.

## 2. Struktur Navigasi Global (Bottom Navigation)

Aturan: 5 tab dengan isi lama, kecuali tiga yang lingkupnya berubah:
**Dashboard / Perangkat / Jadwal / Riwayat / Pengaturan**.

- **Tab "Perangkat"** (ex-`BluetoothPage` berlabel "Device") diubah menjadi
  **registry + pemindai**: daftar semua unit yang tersimpan, bukan lagi daftar
  hasil scan sementara. Tombol "Pindai untuk menambah" ada di sini.
- Tab **Dashboard** menjadi ringkasan armada (seluruh kartu unit).

Alur umum:
```
Dashboard (gambaran semua unit)
   └ tap kartu unit ─────────────► Detail Unit (data tersimpan + pull)
                           └ aksi "Sinkron / Dapatkan data baru"
                           └ aksi "Semprot Sekarang" (unit ini)
Tab Perangkat (registry)
   ├ list unit tersimpan (+ chip Live)
   │    └ swipe/tap → Detail Unit
   └ "Pindai & Tambah" → multi-select unit baru → simpan ke registry
Aksi batch (di tab Perangkat atau Dashboard)
   └ pilih beberapa unit (mode select) → "Semprot Sekarang" / "Terapkan
     Jadwal Sama" → progress → hasil ringkasan sukses/gagal per unit.
```

## 3. Layar Utama (per bagian)

### 3.1 Dashboard (armada)

Bagian atas:
- Header ringkas: judul + kanan **tombol "Aksi Batch"** (mode pilih) dan tombol
  sinkron/refresh.
- Dropdown/summary teratas menampilkan total unit (mis. "12 perangkat · 2
  tersambung · 11 L semprot minggu ini").

Daftar **kartu unit** (scroll vertikal, satu per unit, diurutkan menurut
favorit / nama):
- Pojok kiri: indikator status (dot hijau terang = Live+Ble; abu = offline).
- Baris utama: nama unit (nama tampilan yang bisa diedit), MAC kecil di bawah
  nama, chip "tersambung" bila live, dan tombol kebab (⋮).
- Baris metrik: `Volume hr ini` (ml), `Sesi`, `Baterai %`, `Terakhir aktif`
  (mm/gg hh:mm).
- Bawah: dua aksi cepat — **"Detail"** dan **"Semprot Sekarang"**.
- Bila mode multi-select aktif → setiap kartu punya tanda centang terpilih.

Saat tidak ada unit sama sekali (kosong): ilustrasi & tombol
"Pindai Perangkat Pertama".

Perilaku refresh:
- Bila app terhubung ke sebuah unit dan sedang membuka dashboard, snapshot
  dari pull disimpan → kartu update.
- Bila offline: kartu tetap tampil dari snapshot DB + label waktu
  "terakhir ...".

### 3.2 Detail Unit (satu perangkat)

Ini layar tempat kartu ringkasan menuju ke *detail data*. Bar informasi:
nama besar, MAC, status live/offline, tombol **Sinkron (Refresh)** dan
**Edit Nama**.

Body terbagi tab, data dari DB unit (histori) + snapshot terbaru:

- **Ringkasan** (summary): total ml hari ini & minggu ini (dari logs /
  snapshot), sesi, baterai/tegangan/isSolar; kartu hero hijau mirip day-card
  yang dipakai dashboard saat ini.
- **Statistik**: grafik batang volume per hari (Sen–Min) — dibangun dari
  `spray_logs` per perangkat + data stats hasil pull (widget chart layar
dashboard dipakai ulang).
- **Jadwal**: daftar jadwal perangkat ini (dari `spray_schedules.device_key`);
  pakai toggle on/off. (Lihat §3.4 untuk terapkan ke banyak.)
- **Riwayat**: log semprot unit tersebut (difilter per perangkat) + tanggal.
- **Koneksi/perangkat**: tombol "Hubungkan" bila unit ada di daftar hasil scan
  system devices ataupun live; tempat mengubah SSID/WiFi config unit
  (memakai layar config BLE yang sudah ada).

Berguna juga memperlihatkan "Sinkronkan jadwal ke unit ini" saat tersambung.

### 3.3 Tab Perangkat (registry & pemindai)

Bagian atas — *perangkat tersimpan (registry)*:
- daftar unit (mirip kartu dashboard tapi ringkas), sukai/bintang, tombol
  hapus unit (dengan konfirmasi: hapus juga histori? pilihan di confirm dialog).

Bagian bawah — *Pindai & Tambah*:
- tombol besar "Pindai" memanggil `BluetoothService.startScan()`;
- selama scan, umpan perangkat yang terlihat (nama+MAC+RSSI);
- setiap hasil bisa dipilih (checkbox); setelah berhenti, tombol
  "Tambahkan (n) ke daftar" → masukkan ke registry;
- hasil yang sudah ada di registry ditandai "Sudah ada".

Alur connect: mengetuk unit yang **sudah di registry** → buka Detail; unit
yang baru discan + dipilih → tambah ke registry dulu.

### 3.4 Jadwal — sekarang per unit (+ terapkan ke banyak)

Perubahan pada tab Jadwal: tampilkan **pengelola jadwal untuk perangkat yang
dipilih** dalam dropdown unit (bawaan: perangkat yang sedang terhubung atau
yang terakhir dibuka). Daftar jadwal ditarik dari unit tersebut (pull +
simpan saat terhubung).

Aksi batch:
- pada pengelola, tombol **"Terapkan Jadwal Ini ke Unit Lain..."** → dialog
  pilih beberapa unit tersimpan → konfirmasi.
- selama penerapan menampilkan dialog *progress* per unit.

Secara desain, list jadwal yang ditampilkan konsisten (jam mulai, durasi,
on/off) tapi dihindari duplikasi "global vs per device".

### 3.5 Riwayat

Tab Riwayat diperluas (opsional):
- filter dengan bawaan **Semua unit**; tambah dropdown filter "per unit".
- daftar log tetap per baris (tanggal/jam, unit, durasi, ml, mode) plus
  tombol hapus global dengan peringatan.

## 4. Aksi Multi-Unit (bagian paling penting untuk permintaan user)

### Semprot Sekarang — satu atau banyak unit
- Masuk dari: kartu unit (satu), atau dashboard/Perangkat mode pilih (banyak).
- Dialog konfigurasi durasi: satu stepper menit/detik (mis. 30 dtk) dan
  pilihan apakah berlaku ke seluruh yang dipilih atau per unit beda (awalnya:
  satu durasi untuk semua yang dipilih).
- Setelah OK: **dialog progress** menampilkan satu baris per unit dengan
  status berjalan — mencerminkan operator batch yang menyambung → kirim →
  terima ACK → lepas satu per satu secara berurutan:
  ```
  ESP-SH25-01  ✔ semprot dimulai
  ESP-SH25-02  ✔ semprot dimulai
  ESP-SH25-03  ⚠ offline — dilewati  (dapat dijalankan nanti)
  ```
- Saat selesai: ringkasan sukses/gagal + tombol "Selesai".
- Saat mode pilih aktif, kartu yang terpilih disorot aksen hijau dan tombol
  batch menjadi "Semprot N unit" (N = jumlah terpilih).

### Bila sebagian unit tidak terjangkau
- Jika unit yang dipilih tidak berada dalam jangkauan BLE saat batch jalan,
batch **melewatkan** dan menandal unit itu, bukan menunda seluruh batch.
- Di akhir: laporan jelas "N berhasil, M tidak terjangkau" + petunjuk untuk
menyalakan unit lalu pilih ulang.

**Terapkan Jadwal Sama ke Banyak Unit**
- Dari pengelola jadwal per unit (tab Jadwal) pilih tombol "Terapkan Jadwal
  Ini ke Unit Lain…", centang beberapa unit, konfirmasi.
- Aksi berurutan sama: tiap unit konek → push jadwal → ACK → lepas; progress
  & hasil ditampilkan per unit di dialog yang sama.

## 5. Komponen yang perlu dibuat/dijadikan (struktur & warna)

- `DeviceCard` (dipakai dashboard & registry) — ringkas, dua variasi;
- `DeviceDetailScreen` — layar baru;
- dialog: `BatchProgressDialog`, `DurationDialog`, `MultiPickDialog`;
- kecil: `LiveBadge`, dan *action bar* persisten di bawah yang memadukan
  aksi batch sedang dipilih (agar UI tetap ringkas saat banyak kartu).

> Semua ini memakai kembali kapabilitas yang sudah ada di layar lama
> (`dashboard_page.dart`, `bluetooth_page.dart`, `history_page.dart`,
> `schedule_page.dart`) tetapi mengubah sumber datanya: tidak lagi dari satu
> perangkat aktif, melainkan dari tiap unit di registry (bertinggal + live).

## 6. Ringkasan transit layar lama → baru

| Layar lama | Menjadi | Catatan |
| --- | --- | --- |
| Dashboard (satu device) | Fleet dashboard | kartu per registry unit |
| Bluetooth/Device page (scan sesaat) | Registry + pindaian & tambah banyak | tombol "Pindai & Tambah" |
| Jadwal (global) | Per-unit + aksi "terapkan ke banyak" | filter/per-device |
| Riwayat (global) | Riwayat + filter unit | boleh tetap semua |

Kartu **Detail** diakses dari mana pun kartu/unit muncul (dashboard, tab
Perangkat, riwayat). Layar yang sekarang *dibangun untuk satu perangkat*
tetap ada tetapi mengubah sumber state-nya: dari nilai tunggal
(`deviceRepo.summary`) menjadi per kunci (`deviceStatusByKey(mac)`).

---

Keputusan tampilan yang perlu disetujui sebelum implementasi:
letak *Pindai & Tambah*, mode *selection untuk batch*, dan kedudukan tab
*Jadwal global vs per-unit*.
