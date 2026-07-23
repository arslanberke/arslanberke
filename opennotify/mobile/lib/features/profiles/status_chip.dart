import 'package:flutter/material.dart';

import '../../core/models.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final ProfileStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ProfileStatus.public => (Colors.green, 'Public'),
      ProfileStatus.private => (Colors.amber, 'Private'),
      ProfileStatus.unknown => (Colors.grey, 'Unknown'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
