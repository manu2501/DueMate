import 'package:flutter/material.dart';
import 'package:duemate/data/database/tables.dart';

/// Single source for how an expense category is named, drawn and charted.
extension ExpenseCategoryX on ExpenseCategory {
  String get label => switch (this) {
        ExpenseCategory.groceries => 'Groceries',
        ExpenseCategory.utilities => 'Bills & utilities',
        ExpenseCategory.rent => 'Rent',
        ExpenseCategory.fuel => 'Fuel',
        ExpenseCategory.food => 'Food & dining',
        ExpenseCategory.shopping => 'Shopping',
        ExpenseCategory.entertainment => 'Entertainment',
        ExpenseCategory.health => 'Health',
        ExpenseCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        ExpenseCategory.groceries => Icons.shopping_basket_outlined,
        ExpenseCategory.utilities => Icons.bolt_outlined,
        ExpenseCategory.rent => Icons.home_outlined,
        ExpenseCategory.fuel => Icons.local_gas_station_outlined,
        ExpenseCategory.food => Icons.restaurant_outlined,
        ExpenseCategory.shopping => Icons.shopping_bag_outlined,
        ExpenseCategory.entertainment => Icons.movie_outlined,
        ExpenseCategory.health => Icons.favorite_border_rounded,
        ExpenseCategory.other => Icons.category_outlined,
      };

  /// Categorical chart colour. Only for chart marks; labels and amounts stay
  /// in text colours, and list rows use neutral icons.
  ///
  /// Fixed slot order (category enum order) from a validated categorical
  /// palette: every adjacent pair passes the colour-blind separation and
  /// normal-vision floors in light (on #FFFFFF) and dark (on #171B19).
  /// Three light slots are under 3:1 contrast, so every mark must ship with a
  /// visible text label. "Other" is neutral grey, not a ninth hue.
  Color chartColor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      ExpenseCategory.groceries => dark ? const Color(0xFF3987E5) : const Color(0xFF2A78D6),
      ExpenseCategory.utilities => dark ? const Color(0xFFD95926) : const Color(0xFFEB6834),
      ExpenseCategory.rent => dark ? const Color(0xFF199E70) : const Color(0xFF1BAF7A),
      ExpenseCategory.fuel => dark ? const Color(0xFFC98500) : const Color(0xFFEDA100),
      ExpenseCategory.food => dark ? const Color(0xFFD55181) : const Color(0xFFE87BA4),
      ExpenseCategory.shopping => const Color(0xFF008300),
      ExpenseCategory.entertainment => dark ? const Color(0xFF9085E9) : const Color(0xFF6250D6),
      ExpenseCategory.health => dark ? const Color(0xFFE66767) : const Color(0xFFE34948),
      ExpenseCategory.other => dark ? const Color(0xFF7D8480) : const Color(0xFF8C918E),
    };
  }
}
