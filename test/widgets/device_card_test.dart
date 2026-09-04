import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alburdat_dashboard/models/esp_device.dart';
import 'package:alburdat_dashboard/widgets/device_card.dart';

void main() {
  Widget buildCard({bool isLive = false}) => DeviceCard(
        device: const EspDevice(deviceKey: 'AA:BB:CC:DD:EE:FF', name: 'ESP-1'),
        snapshotFuture: Future.value(null),
        isLive: isLive,
        onShowDetail: () {},
        onSprayNow: isLive ? () {} : null,
      );

  Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: card)));

  group('DeviceCard (M3 fleet)', () {
    testWidgets('menampilkan nama & MAC + aksi Detail', (tester) async {
      await pump(tester, buildCard(isLive: false));
      expect(find.text('ESP-1'), findsOneWidget);
      expect(find.text('AA:BB:CC:DD:EE:FF'), findsOneWidget);
      expect(find.text('Detail'), findsOneWidget);
    });

    testWidgets('live menampilkan chip Live & tombol Semprot', (tester) async {
      await pump(tester, buildCard(isLive: true));
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Semprot'), findsOneWidget);
    });

    testWidgets('offline tidak menampilkan chip Live & Semprot',
        (tester) async {
      await pump(tester, buildCard(isLive: false));
      expect(find.text('Live'), findsNothing);
      expect(find.text('Semprot'), findsNothing);
    });
  });
}
