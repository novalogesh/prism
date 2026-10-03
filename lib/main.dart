import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_page.dart';
import 'features/map/map_page.dart';
import 'features/report/report_page.dart';
import 'features/reports/reports_page.dart';
import 'features/weather/weather_page.dart';

void main() {
  runApp(const PrismApp());
}

class PrismApp extends StatelessWidget {
  const PrismApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PRISM',
      theme: AppTheme.light(),
      home: const PrismShell(),
    );
  }
}

class PrismShell extends StatefulWidget {
  const PrismShell({super.key});

  @override
  State<PrismShell> createState() => _PrismShellState();
}

class _PrismShellState extends State<PrismShell> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    HomePage(onNavigate: _onDestinationSelected),
    const MapPage(),
    const ReportPage(),
    const ReportsPage(),
    const WeatherPage(),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_alert_outlined),
            selectedIcon: Icon(Icons.add_alert),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Weather',
          ),
        ],
      ),
    );
  }
}
