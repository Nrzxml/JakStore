import 'package:flutter/material.dart';

import '../data/inventory_store.dart';
import '../models/inventory.dart';
import '../screens/dashboard_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/scan_screen.dart';
import '../services/device_identification_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.store,
    this.deviceIdentificationService =
        const UnconfiguredDeviceIdentificationService(),
    this.onLogout,
    super.key,
  });

  final InventoryStore store;
  final DeviceIdentificationService deviceIdentificationService;
  final VoidCallback? onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(store: widget.store, onNavigate: _navigate),
      InventoryScreen(store: widget.store),
      ScanScreen(
        store: widget.store,
        deviceIdentificationService: widget.deviceIdentificationService,
        onOpenUnit: _openUnit,
        onRegisterUnknownImei: (
          imei, {
          initialModelId,
          identifiedModelId,
          identifiedModelName,
        }) =>
            showAddUnitSheet(
          context,
          widget.store,
          initialImei: imei,
          initialModelId: initialModelId,
          identifiedModelId: identifiedModelId,
          identifiedModelName: identifiedModelName,
        ),
      ),
      ReportsScreen(store: widget.store),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        actions: [
          if (widget.onLogout != null)
            IconButton(
              tooltip: 'Keluar',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
        ],
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFFF6A2A),
              child: Text(
                'J',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JAKSTORE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: Colors.white60,
                  ),
                ),
                Text(
                  'Warehouse OS',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: _navigate,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventori',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }

  void _navigate(int index) => setState(() => selectedIndex = index);

  void _openUnit(PhoneUnit unit) {
    final variant = widget.store.variantFor(unit.variantId);
    if (variant == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnitDetailScreen(
          store: widget.store,
          unitId: unit.id,
        ),
      ),
    );
  }
}
