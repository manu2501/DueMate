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
        return 'Money Given';
      case TransactionType.paymentReceived:
        return 'Payment Received';
    }
  }

  String get actionLabel {
    switch (this) {
      case TransactionType.moneyGiven:
        return 'Give Money';
      case TransactionType.paymentReceived:
        return 'Receive Payment';
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
  String get label {
    switch (this) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethod.upi:
        return Icons.qr_code_scanner_rounded;
      case PaymentMethod.cash:
        return Icons.payments_outlined;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance_outlined;
      case PaymentMethod.card:
        return Icons.credit_card_outlined;
      case PaymentMethod.other:
        return Icons.more_horiz_rounded;
    }
  }
}

