import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'dashboard_page.dart';
import 'bluetooth_page.dart';
import 'schedule_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    BluetoothPage(),
    SchedulePage(),
    HistoryPage(),
    SettingsPage(),
  ];

  final List<_NavItemData> _navItems = const [
    _NavItemData(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    _NavItemData(icon: Icons.memory_outlined, activeIcon: Icons.memory, label: 'Device'),
    _NavItemData(icon: Icons.alarm_outlined, activeIcon: Icons.alarm, label: 'Jadwal'),
    _NavItemData(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Riwayat'),
    _NavItemData(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Pengaturan'),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final safeIndex = (_currentIndex >= 0 && _currentIndex < _pages.length) ? _currentIndex : 0;

    final barColor = isDark ? ThemeProvider.darkBgColor : Colors.white;
    const activePillColor = Color(0xFF2C2D32);
    const activeAccent = ThemeProvider.greenAccentColor;
    final unselectedColor = isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade600;
    final borderColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E7EB);

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: barColor,
          border: Border(
            top: BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = safeIndex == index;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: isSelected
                        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                        : const EdgeInsets.all(10),
                    decoration: isSelected
                        ? BoxDecoration(
                            color: activePillColor,
                            borderRadius: BorderRadius.circular(20),
                          )
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected ? activeAccent : unselectedColor,
                          size: 20,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontFamily: 'Utendo',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: activeAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
