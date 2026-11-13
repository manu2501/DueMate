import 'package:flutter/material.dart';
import '../../data/database/tables.dart';

class AppConstants {
  static const String appName = 'DueMate';
  static const String appTagline = 'Personal Lending & Repayment Tracker';

  // App Versioning
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;
  static const String appVersionString = 'v$appVersion+$appBuildNumber';

  // Self / Personal Vault Constants
  static const String selfPersonId = 'self_person_me';
  static const String selfPersonName = 'Myself (Personal)';

  // Currency
  static const String defaultCurrencySymbol = '₹';
  static const String defaultCurrencyCode = 'INR';

  static const List<CurrencyOption> supportedCurrencies = [
    CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    CurrencyOption(code: 'USD', symbol: '\$', name: 'US Dollar'),
    CurrencyOption(code: 'EUR', symbol: '€', name: 'Euro'),
    CurrencyOption(code: 'GBP', symbol: '£', name: 'British Pound'),
    CurrencyOption(code: 'AED', symbol: 'AED', name: 'UAE Dirham'),
    CurrencyOption(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar'),
    CurrencyOption(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
    CurrencyOption(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
  ];
}

class CurrencyOption {
  final String code;
  final String symbol;
  final String name;

  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.name,
  });
}

extension TransactionTypeX on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.moneyGiven:
        return 'Money given';
      case TransactionType.paymentReceived:
        return 'Payment received';
    }
  }

  String get actionLabel {
    switch (this) {
      case TransactionType.moneyGiven:
        return 'Give money';
      case TransactionType.paymentReceived:
        return 'Receive payment';
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionType.moneyGiven:
        return Icons.arrow_outward_rounded;
      case TransactionType.paymentReceived:
        return Icons.arrow_downward_rounded;
    }
  }

  Color get color {
    switch (this) {
      case TransactionType.moneyGiven:
        return const Color(0xFFDC2626); // Red-600
      case TransactionType.paymentReceived:
        return const Color(0xFF16A34A); // Green-600
    }
  }
}

extension PaymentMethodX on PaymentMethod {
  /// Order for pickers and filters: "Other" last (the enum's stored order
  /// has later additions after it).
  static final ordered = [
    for (final m in PaymentMethod.values)
      if (m != PaymentMethod.other) m,
    PaymentMethod.other,
  ];

  String get label => switch (this) {
        PaymentMethod.upi => 'UPI',
        PaymentMethod.cash => 'Cash',
        PaymentMethod.bankTransfer => 'Bank transfer',
        PaymentMethod.card => 'Card',
        PaymentMethod.wallet => 'Wallet',
        PaymentMethod.other => 'Other',
      };

  IconData get icon => switch (this) {
        PaymentMethod.upi => Icons.qr_code_scanner_rounded,
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.bankTransfer => Icons.account_balance_outlined,
        PaymentMethod.card => Icons.credit_card_outlined,
        PaymentMethod.wallet => Icons.account_balance_wallet_outlined,
        PaymentMethod.other => Icons.more_horiz_rounded,
      };
}

