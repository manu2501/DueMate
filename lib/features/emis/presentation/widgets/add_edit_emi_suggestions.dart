import 'package:flutter/material.dart';
import 'package:duemate/core/widgets/suggest_text_field.dart';

class EmiItemSuggestion {
  final String label;
  final String fillValue;
  final IconData icon;

  const EmiItemSuggestion(this.label, this.fillValue, this.icon);

  Suggestion get asSuggestion => Suggestion(label: label, fillValue: fillValue, icon: icon);
}

class EmiCardSuggestion {
  final String name;
  final String fillValue;
  final IconData icon;
  final Color color;

  const EmiCardSuggestion(this.name, this.fillValue, this.icon, this.color);

  Suggestion get asSuggestion =>
      Suggestion(label: name, fillValue: fillValue, icon: icon, iconColor: color);
}

class EmiSuggestionsData {
  static const List<EmiItemSuggestion> itemSuggestions = [
    EmiItemSuggestion('iPhone / Mobile', 'iPhone', Icons.phone_iphone_rounded),
    EmiItemSuggestion('MacBook / Laptop', 'MacBook Laptop', Icons.laptop_mac_rounded),
    EmiItemSuggestion('iPad / Tablet', 'iPad Tablet', Icons.tablet_mac_rounded),
    EmiItemSuggestion('Smartwatch', 'Smartwatch', Icons.watch_rounded),
    EmiItemSuggestion('Headphones', 'Headphones', Icons.headphones_rounded),
    EmiItemSuggestion('Smart TV', 'Smart TV', Icons.tv_rounded),
    EmiItemSuggestion('Air Conditioner', 'Air Conditioner', Icons.ac_unit_rounded),
    EmiItemSuggestion('Refrigerator', 'Refrigerator', Icons.kitchen_rounded),
    EmiItemSuggestion('Washing Machine', 'Washing Machine', Icons.local_laundry_service_rounded),
    EmiItemSuggestion('Flight Tickets', 'Flight Tickets', Icons.flight_takeoff_rounded),
    EmiItemSuggestion('Hotel / Stay', 'Hotel Booking', Icons.hotel_rounded),
    EmiItemSuggestion('Camera / Gadget', 'Camera', Icons.photo_camera_rounded),
    EmiItemSuggestion('Bike / Scooter', 'Two Wheeler', Icons.two_wheeler_rounded),
    EmiItemSuggestion('Furniture / Sofa', 'Furniture', Icons.chair_rounded),
    EmiItemSuggestion('Jewelry / Gold', 'Jewelry', Icons.diamond_rounded),
    EmiItemSuggestion('Medical / Dental', 'Medical Treatment', Icons.local_hospital_rounded),
    EmiItemSuggestion('Course / Study', 'Education Course', Icons.school_rounded),
    EmiItemSuggestion('Microwave / Oven', 'Microwave Oven', Icons.microwave_rounded),
    EmiItemSuggestion('Gaming / PS5', 'Gaming Console', Icons.sports_esports_rounded),
    EmiItemSuggestion('Shopping / Clothes', 'Shopping', Icons.shopping_bag_outlined),
  ];

  static const List<EmiItemSuggestion> loanPurposeSuggestions = [
    EmiItemSuggestion('Personal Loan', 'Personal Loan', Icons.person_outline_rounded),
    EmiItemSuggestion('Emergency Loan', 'Emergency Loan', Icons.health_and_safety_outlined),
    EmiItemSuggestion('Education Loan', 'Education Loan', Icons.school_rounded),
    EmiItemSuggestion('Vehicle / Bike', 'Vehicle Loan', Icons.two_wheeler_rounded),
    EmiItemSuggestion('Business Loan', 'Business Loan', Icons.storefront_rounded),
    EmiItemSuggestion('Home / Rent Loan', 'Home Rent Loan', Icons.home_outlined),
    EmiItemSuggestion('Cash Advance', 'Cash Advance', Icons.payments_outlined),
    EmiItemSuggestion('Medical Loan', 'Medical Loan', Icons.local_hospital_rounded),
    EmiItemSuggestion('Wedding Loan', 'Wedding Loan', Icons.celebration_rounded),
    EmiItemSuggestion('Travel Loan', 'Travel Loan', Icons.flight_takeoff_rounded),
    EmiItemSuggestion('Gadget Loan', 'Gadget Loan', Icons.devices_other_rounded),
    EmiItemSuggestion('Salary Advance', 'Salary Advance', Icons.work_outline_rounded),
  ];

  static const List<EmiCardSuggestion> cardSuggestions = [
    EmiCardSuggestion('HDFC Bank', 'HDFC Credit Card', Icons.account_balance_rounded, Color(0xFF004C8F)),
    EmiCardSuggestion('ICICI Bank', 'ICICI Credit Card', Icons.credit_card_rounded, Color(0xFFB02A30)),
    EmiCardSuggestion('SBI Card', 'SBI Credit Card', Icons.credit_score_rounded, Color(0xFF0A66C2)),
    EmiCardSuggestion('Axis Bank', 'Axis Credit Card', Icons.account_balance_wallet_rounded, Color(0xFF97144D)),
    EmiCardSuggestion('Kotak', 'Kotak Credit Card', Icons.account_balance_rounded, Color(0xFFED1C24)),
    EmiCardSuggestion('Amex', 'Amex Credit Card', Icons.credit_card_rounded, Color(0xFF0077A6)),
    EmiCardSuggestion('OneCard', 'OneCard', Icons.style_rounded, Color(0xFF1E293B)),
    EmiCardSuggestion('IndusInd', 'IndusInd Credit Card', Icons.account_balance_rounded, Color(0xFF8B1D24)),
    EmiCardSuggestion('RBL Bank', 'RBL Credit Card', Icons.credit_card_rounded, Color(0xFF0B3B60)),
    EmiCardSuggestion('IDFC FIRST', 'IDFC FIRST Card', Icons.account_balance_rounded, Color(0xFF861F41)),
    EmiCardSuggestion('Federal Bank', 'Federal Credit Card', Icons.account_balance_rounded, Color(0xFF002B49)),
    EmiCardSuggestion('Standard Chartered', 'StanChart Card', Icons.credit_card_rounded, Color(0xFF009933)),
    EmiCardSuggestion('Bank of Baroda', 'BOB Credit Card', Icons.account_balance_rounded, Color(0xFFE84E1B)),
    EmiCardSuggestion('HSBC', 'HSBC Credit Card', Icons.account_balance_rounded, Color(0xFFDB0011)),
    EmiCardSuggestion('AU Small Finance', 'AU Bank Card', Icons.credit_card_rounded, Color(0xFF6B21A8)),
    EmiCardSuggestion('Yes Bank', 'Yes Bank Card', Icons.account_balance_rounded, Color(0xFF005A9C)),
    EmiCardSuggestion('PNB', 'PNB Credit Card', Icons.account_balance_rounded, Color(0xFF9A1B2F)),
    EmiCardSuggestion('Canara Bank', 'Canara Bank Card', Icons.account_balance_rounded, Color(0xFF00529B)),
    EmiCardSuggestion('Union Bank', 'Union Bank Card', Icons.account_balance_rounded, Color(0xFF003366)),
  ];

  static const List<EmiCardSuggestion> loanSourceSuggestions = [
    EmiCardSuggestion('Cash Loan', 'Cash Loan', Icons.payments_rounded, Color(0xFF059669)),
    EmiCardSuggestion('Bank Transfer', 'Bank Transfer Loan', Icons.account_balance_rounded, Color(0xFF0284C7)),
    EmiCardSuggestion('UPI Transfer', 'UPI Loan', Icons.qr_code_rounded, Color(0xFF7C3AED)),
    EmiCardSuggestion('SBI Loan', 'SBI Personal Loan', Icons.account_balance_rounded, Color(0xFF0A66C2)),
    EmiCardSuggestion('HDFC Loan', 'HDFC Personal Loan', Icons.account_balance_rounded, Color(0xFF004C8F)),
    EmiCardSuggestion('ICICI Loan', 'ICICI Personal Loan', Icons.account_balance_rounded, Color(0xFFB02A30)),
    EmiCardSuggestion('Axis Bank', 'Axis Bank Loan', Icons.account_balance_wallet_rounded, Color(0xFF97144D)),
    EmiCardSuggestion('Kotak Loan', 'Kotak Loan', Icons.account_balance_rounded, Color(0xFFED1C24)),
    EmiCardSuggestion('NBFC / FinTech', 'FinTech Loan', Icons.domain_rounded, Color(0xFFD97706)),
    EmiCardSuggestion('Cheque Loan', 'Cheque Loan', Icons.receipt_long_rounded, Color(0xFF475569)),
    EmiCardSuggestion('Peer to Peer', 'P2P Loan', Icons.handshake_rounded, Color(0xFF0D9488)),
  ];

  static const List<int> defaultTenureOptions = [3, 6, 9, 12, 18, 24, 36];
}
