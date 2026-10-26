import 'package:flutter/material.dart';

import '../models/inventory.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final UnitStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      UnitStatus.available => const Color(0xFF16845B),
      UnitStatus.sold => const Color(0xFF697386),
      UnitStatus.service => const Color(0xFFB7791F),
      UnitStatus.damaged => const Color(0xFFC2413A),
      UnitStatus.returned => const Color(0xFF6554C0),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          status.label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
