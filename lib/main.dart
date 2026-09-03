import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/bluetooth_service.dart';
import 'services/database_helper.dart';
import 'services/mqtt_service.dart';
import 'services/device_repository.dart';
import 'services/theme_provider.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<DatabaseHelper>(
          create: (_) => DatabaseHelper.instance,
        ),
        ChangeNotifierProvider<BluetoothService>(
          create: (_) => BluetoothService(),
        ),
        ChangeNotifierProvider<MqttService>(
          create: (_) => MqttService(),
        ),
      ],
      child: ChangeNotifierProxyProvider2<BluetoothService, MqttService,
          DeviceRepository>(
        create: (context) => DeviceRepository(
          bluetoothService: context.read<BluetoothService>(),
          mqttService: context.read<MqttService>(),
          // TODO(dev-demo): Aktifkan MENJELANG pratinjau UI tanpa hardware.
          // Menghasilkan statistik dummy acak 60–67 ml per hari pada chart
          // DASHBOARD ketika perangkat tidak terhubung. Matikan (false) sebelum
          // rilis — data dummy hanya tampil saat offline.
          enableDemoData: true,
        ),
        update: (context, bt, mqtt, previous) => previous!,
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return MaterialApp(
              title: 'Smart Sprayer AI & IoT',
              debugShowCheckedModeBanner: false,
              theme: themeProvider.darkThemeData,
              darkTheme: themeProvider.darkThemeData,
              themeMode: ThemeMode.dark,
              home: const MainNavigationScreen(),
            );
          },
        ),
      ),
    );
  }
}
