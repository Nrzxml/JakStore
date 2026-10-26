import 'package:flutter/material.dart';

import 'data/inventory_store.dart';
import 'services/jakstore_api_client.dart';
import 'services/device_identification_service.dart';
import 'widgets/auth_gate.dart';
import 'widgets/app_shell.dart';

void main() {
  const apiBaseUrl = String.fromEnvironment('JAKSTORE_API_BASE_URL');
  if (apiBaseUrl.trim().isEmpty) {
    runApp(
      JakStoreAdminApp(
        store: InventoryStore(),
        deviceIdentificationService:
            const UnconfiguredDeviceIdentificationService(),
      ),
    );
  } else {
    final apiClient = JakStoreApiClient(baseUrl: apiBaseUrl);
    runApp(
      JakStoreAdminApp(
        store: InventoryStore(apiClient: apiClient),
        apiClient: apiClient,
      ),
    );
  }
}

class JakStoreAdminApp extends StatelessWidget {
  const JakStoreAdminApp({
    required this.store,
    this.deviceIdentificationService =
        const UnconfiguredDeviceIdentificationService(),
    this.apiClient,
    super.key,
  });

  final InventoryStore store;
  final DeviceIdentificationService deviceIdentificationService;
  final JakStoreApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF10172A);
    const orange = Color(0xFFFF6A2A);

    return MaterialApp(
      title: 'JakStore Gudang',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: orange,
          primary: orange,
          secondary: navy,
          surface: const Color(0xFFF7F8FC),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE8EAF0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: orange, width: 1.5),
          ),
        ),
      ),
      home: apiClient == null
          ? AppShell(
              store: store,
              deviceIdentificationService: deviceIdentificationService,
            )
          : AuthGate(apiClient: apiClient!, store: store),
    );
  }
}
