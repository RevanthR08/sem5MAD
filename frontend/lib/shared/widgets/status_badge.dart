import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool showDot;

  const StatusBadge({
    super.key,
    required this.status,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'SUBMITTED':
      case 'ROUTED':
        bg = const Color(0xFF1A1A1A);
        fg = const Color(0xFFE5E5E5);
        label = status == 'ROUTED' ? 'ROUTED' : 'REPORTED';
        break;
      case 'ACKNOWLEDGED':
      case 'ASSIGNED':
        bg = const Color(0xFF241C10);
        fg = const Color(0xFFFBBF24);
        label = status == 'ASSIGNED' ? 'DISPATCHED' : 'ACKNOWLEDGED';
        break;
      case 'IN_PROGRESS':
        bg = const Color(0xFF142434);
        fg = const Color(0xFF38BDF8);
        label = 'IN PROGRESS';
        break;
      case 'RESOLUTION_SUBMITTED':
        bg = const Color(0xFF2E2305);
        fg = const Color(0xFFFDE047);
        label = 'VERIFY RESOLUTION';
        break;
      case 'RESOLVED':
        bg = const Color(0xFF0F291E);
        fg = const Color(0xFF4ADE80);
        label = 'RESOLVED';
        break;
      case 'REOPENED':
        bg = const Color(0xFF2E1010);
        fg = const Color(0xFFF87171);
        label = 'REOPENED';
        break;
      default:
        bg = const Color(0xFF1F1F1F);
        fg = const Color(0xFFA3A3A3);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3), // Almost square
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
