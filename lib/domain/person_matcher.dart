import 'package:duemate/domain/entities/person.dart';

/// Decides whether a name/phone pair refers to someone already in the ledger.
abstract final class PersonMatcher {
  static final _nonDigits = RegExp(r'\D');

  /// Digits only, keeping the last 10 so "+91 98765 43210" and "9876543210"
  /// compare equal.
  static String normalizePhone(String? raw) {
    if (raw == null) return '';
    final digits = raw.replaceAll(_nonDigits, '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  /// Returns the existing person this would duplicate, or null.
  ///
  /// When both sides have a phone number, the numbers decide. A name only
  /// counts when one side has no number, so two different people who share a
  /// name can both be added. Phone matches win over name matches.
  static Person? findDuplicate(
    Iterable<Person> people, {
    required String name,
    String? phone,
    String? excludeId,
  }) {
    final wantName = name.trim().toLowerCase();
    final wantPhone = normalizePhone(phone);
    final candidates = people.where((p) => p.id != excludeId).toList();

    if (wantPhone.isNotEmpty) {
      for (final p in candidates) {
        if (normalizePhone(p.phone) == wantPhone) return p;
      }
    }
    if (wantName.isEmpty) return null;
    for (final p in candidates) {
      final theirPhone = normalizePhone(p.phone);
      final phonesDecide = wantPhone.isNotEmpty && theirPhone.isNotEmpty;
      if (!phonesDecide && p.name.trim().toLowerCase() == wantName) return p;
    }
    return null;
  }
}
