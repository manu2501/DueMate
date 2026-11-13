/// UPI payment links (the `upi://pay` format every Indian UPI app reads,
/// from QR codes or as an intent). Pure logic, no Flutter.
class Upi {
  Upi._();

  /// UPI only moves rupees.
  static const currencySymbol = '₹';

  // handle@psp: handle is letters, digits, dot, hyphen, underscore; the
  // provider part starts with a letter (okhdfcbank, ybl, paytm, upi, ...).
  static final _idPattern = RegExp(r'^[a-zA-Z0-9._-]{2,256}@[a-zA-Z][a-zA-Z0-9.-]{1,63}$');

  /// Trims and lower-cases a typed UPI ID (IDs are case-insensitive).
  static String normalizeId(String raw) => raw.trim().toLowerCase();

  static bool isValidId(String raw) => _idPattern.hasMatch(normalizeId(raw));

  /// Form-field validator for an optional UPI ID.
  static String? validateOptionalId(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return null;
    return isValidId(t) ? null : 'Check the UPI ID, e.g. name@okhdfcbank';
  }

  /// Builds a `upi://pay` link. [amount] is optional: without it the payer
  /// types the amount. Values are percent-encoded with `%20` for spaces
  /// (some UPI apps show a literal `+`).
  static Uri payUri({
    required String payeeId,
    String? payeeName,
    double? amount,
    String? note,
  }) {
    final params = <String, String>{
      'pa': normalizeId(payeeId),
      if (payeeName != null && payeeName.trim().isNotEmpty) 'pn': _clip(payeeName.trim(), 50),
      if (amount != null && amount > 0) 'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      if (note != null && note.trim().isNotEmpty) 'tn': _clip(note.trim(), 50),
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return Uri.parse('upi://pay?$query');
  }

  static String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);
}
