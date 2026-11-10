import 'package:flutter/material.dart';

/// Navigation dock icons matching each section of DueMate:
/// 0: Dashboard (Dashboard)
/// 1: Ledger (Book / Ledger)
/// 2: Transactions (Receipt / Transactions)
class DockNavIcon extends StatelessWidget {
  final int index;
  final bool isSelected;
  final Color color;
  final double size;

  const DockNavIcon({
    super.key,
    required this.index,
    required this.isSelected,
    required this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (index) {
      case 0:
        icon = isSelected ? Icons.dashboard_rounded : Icons.dashboard_outlined;
        break;
      case 1:
        icon = isSelected ? Icons.menu_book_rounded : Icons.menu_book_outlined;
        break;
      case 2:
      default:
        icon = isSelected ? Icons.receipt_long_rounded : Icons.receipt_long_outlined;
        break;
    }

    return Icon(
      icon,
      color: color,
      size: size,
    );
  }
}

