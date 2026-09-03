# Task List: Fitur Baca/Tulis Data ESP (Device Sync)

> Dokumen pendamping: `tasks/plan.md` (berisi kontrak JSON, keputusan arsitektur, risiko).

## Phase 0: Fondasi kontrak & model
- [x] Task 1: Model `DailyVolumeStat` + parser kontrak (`lib/models/daily_volume_stat.dart`) + helper tanggal → index Sen–Min + unit test
- [x] Task 2: `MqttService` — topik `response`, parse envelope, stream hasil, method request + timeout (`lib/services/mqtt_service.dart`)
- [x] Task 3: `BluetoothService` — buffer newline, parse envelope, stream hasil, method request (`lib/services/bluetooth_service.dart`)

> Catatan: Task 2/Task 3 meletakkan timeout/retry di `DeviceRepository` (Task 4) agar tidak diduplikasi per kanal.

**Checkpoint:** `flutter analyze` bersih, unit test parser lolos, uji manual stream response tiruan.

## Phase 1: Repository + Kesimpulan & Daya (Item 1 & 3)
- [x] Task 4: `DeviceRepository` (kanal aktif, refreshAll, pull/push schedules, auto-refresh saat connect) + daftarkan di `lib/main.dart`
- [x] Task 5: Dashboard Hero Card & Sistem Daya Kebun dari `DeviceRepository.summary`; hapus dummy & increment lokal

**Checkpoint:** Card kesimpulan & daya menampilkan data ESP; tanpa nilai dummy.

## Phase 2: Statistik Volume (Item 2)
- [ ] Task 6: `_buildStatisticChartCard` dari `DeviceRepository.stats` (7 hari) + fallback SQLite offline

**Checkpoint:** Chart = data ESP; fallback offline tetap tampil.

## Phase 3: Jadwal Semprot (Item 5)
- [x] Task 7: `SchedulePage` stateful — pull jadwal saat connect, timpa DB lokal, seed sekali saat ESP kosong
- [x] Task 8: Auto push `set_schedules` setelah tambah/hapus/toggle; tombol sync jadi cadangan; notifikasi sukses/gagal

**Checkpoint:** Connect → jadwal ESP tampil; perubahan tersimpan di ESP setelah restart.

## Phase 4: Polish & dokumentasi
- [x] Task 9: State error & notifikasi — auto-pull/jadwal saat connect tidak mem-banner error; push diserialkan agar ACK tidak “nyilih” antar operasi cepat
- [x] Task 10: Update `docs/API_REFERENCE.md` (Device Sync) & `docs/ARCHITECTURE.md` (bag. 14 Device Sync)

**Checkpoint:** `flutter analyze` bersih, test lolos, skenario end-to-end connect→pull→ubah→restart ESP.
