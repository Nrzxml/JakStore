import 'package:flutter/material.dart';

import '../data/inventory_store.dart';
import '../models/inventory.dart';
import '../widgets/status_badge.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.store,
    required this.onNavigate,
    super.key,
  });

  final InventoryStore store;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final lowStock = store.variants
            .where((variant) => store.availableFor(variant.id) <= 2)
            .length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
          children: [
            Text(
              'Ringkasan gudang',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF10172A),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Pantau kondisi inventori JakStore hari ini.',
              style: TextStyle(color: Color(0xFF778196)),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _MetricCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Stok tersedia',
                  value: '${store.countStatus(UnitStatus.available)} unit',
                  tint: const Color(0xFFFF6A2A),
                ),
                _MetricCard(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Barang masuk hari ini',
                  value: '${store.incomingToday} unit',
                  tint: const Color(0xFF16845B),
                ),
                _MetricCard(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Barang keluar hari ini',
                  value: '${store.outgoingToday} unit',
                  tint: const Color(0xFFC2413A),
                ),
                _MetricCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Varian stok rendah',
                  value: '$lowStock varian',
                  tint: const Color(0xFFB7791F),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Aksi cepat',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                TextButton(
                  onPressed: () => onNavigate(1),
                  child: const Text('Lihat inventori'),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.qr_code_scanner,
                    label: 'Scan IMEI',
                    subtitle: 'Barang masuk & keluar',
                    onTap: () => onNavigate(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.bar_chart_rounded,
                    label: 'Laporan stok',
                    subtitle: 'Ringkasan per status',
                    onTap: () => onNavigate(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Aktivitas terbaru',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ...store.recentMovements.take(4).map(
                  (movement) => _MovementTile(store: store, movement: movement),
                ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1D2846),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 22),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF778196)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF10172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFFFF6A2A)),
              const SizedBox(height: 16),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF778196)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.store, required this.movement});

  final InventoryStore store;
  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final unit = store.unitById(movement.unitId);
    final variant = unit == null ? null : store.variantFor(unit.variantId);
    final color = switch (movement.type) {
      MovementType.incoming => const Color(0xFF16845B),
      MovementType.outgoing => const Color(0xFFC2413A),
      MovementType.statusChanged => const Color(0xFF6554C0),
    };
    final icon = switch (movement.type) {
      MovementType.incoming => Icons.south_west_rounded,
      MovementType.outgoing => Icons.north_east_rounded,
      MovementType.statusChanged => Icons.sync_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  variant == null
                      ? 'Unit ${movement.imei}'
                      : store.displayNameFor(variant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${movement.type.label} • ${movement.imei}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF778196),
                  ),
                ),
              ],
            ),
          ),
          if (variant != null)
            StatusBadge(status: unit?.status ?? UnitStatus.available),
        ],
      ),
    );
  }
}
