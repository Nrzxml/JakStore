import 'package:flutter/material.dart';

import '../data/inventory_store.dart';
import '../models/inventory.dart';
import '../widgets/status_badge.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({required this.store, super.key});

  final InventoryStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          children: [
            Text(
              'Laporan stok',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF10172A),
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              store.apiClient == null
                  ? 'Ringkasan dihitung dari unit fisik dan mutasi mock.'
                  : 'Ringkasan dihitung dari data server JakStore.',
              style: TextStyle(color: Color(0xFF778196), fontSize: 12),
            ),
            const SizedBox(height: 18),
            _StatusSummary(
              label: 'Tersedia',
              status: UnitStatus.available,
              count: store.countStatus(UnitStatus.available),
              color: const Color(0xFF16845B),
            ),
            _StatusSummary(
              label: 'Terjual',
              status: UnitStatus.sold,
              count: store.countStatus(UnitStatus.sold),
              color: const Color(0xFF697386),
            ),
            _StatusSummary(
              label: 'Servis',
              status: UnitStatus.service,
              count: store.countStatus(UnitStatus.service),
              color: const Color(0xFFB7791F),
            ),
            _StatusSummary(
              label: 'Rusak',
              status: UnitStatus.damaged,
              count: store.countStatus(UnitStatus.damaged),
              color: const Color(0xFFC2413A),
            ),
            const SizedBox(height: 18),
            const Text(
              'Stok per model',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 9),
            ...store.models.map((model) {
              final units = store.unitsForModel(model.id);
              final available = units
                  .where((unit) => unit.status == UnitStatus.available)
                  .length;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.smartphone,
                      color: Color(0xFFFF6A2A),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          Text('${units.length} unit fisik'),
                        ],
                      ),
                    ),
                    Text(
                      '$available / ${units.length}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text(
              'Mutasi terbaru',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 9),
            ...store.recentMovements.map((movement) {
              final unit = store.unitById(movement.unitId);
              final variant =
                  unit == null ? null : store.variantFor(unit.variantId);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      movement.type == MovementType.incoming
                          ? Icons.south_west
                          : movement.type == MovementType.outgoing
                              ? Icons.north_east
                              : Icons.sync,
                      color: movement.type == MovementType.incoming
                          ? const Color(0xFF16845B)
                          : movement.type == MovementType.outgoing
                              ? const Color(0xFFC2413A)
                              : const Color(0xFF6554C0),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            variant == null
                                ? 'Unit tidak ditemukan'
                                : store.displayNameFor(variant),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${movement.type.label} • ${maskImei(movement.imei)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF778196),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unit != null) StatusBadge(status: unit.status),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.label,
    required this.status,
    required this.count,
    required this.color,
  });

  final String label;
  final UnitStatus status;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            StatusBadge(status: status),
            const SizedBox(width: 12),
            SizedBox(
              width: 23,
              child: Text(
                '$count',
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
}
