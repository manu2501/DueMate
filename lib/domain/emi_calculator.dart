import 'dart:math' as math;

/// Result of working out an installment plan.
class EmiPlan {
  /// Original amount before interest and charges (0 = not known).
  final double principal;

  /// Interest over the whole tenure (0 when unknown).
  final double interest;

  /// One-time charges: processing fee, GST, etc.
  final double charges;

  /// What the installments add up to (monthly × months).
  final double totalPayable;

  /// Amount of each installment.
  final double monthly;

  final int months;

  /// Whether [charges] are already inside [totalPayable] (split mode) or are
  /// billed separately on top of it (known-EMI mode).
  final bool chargesInsideEmi;

  const EmiPlan({
    required this.principal,
    required this.interest,
    required this.charges,
    required this.totalPayable,
    required this.monthly,
    required this.months,
    required this.chargesInsideEmi,
  });

  static const empty = EmiPlan(
    principal: 0,
    interest: 0,
    charges: 0,
    totalPayable: 0,
    monthly: 0,
    months: 0,
    chargesInsideEmi: true,
  );

  bool get isValid => monthly > 0 && months > 0;

  /// Everything the borrower pays out of pocket, charges included.
  double get totalCost => chargesInsideEmi ? totalPayable : totalPayable + charges;

  /// Cost over and above the original amount. Null when the original amount
  /// is not known.
  double? get extraCost => principal > 0 ? (totalCost - principal) : null;
}

class EmiCalculator {
  EmiCalculator._();

  static const double defaultGstPercent = 18;

  static double _round2(double v) => double.parse(v.toStringAsFixed(2));

  /// Interest over the tenure.
  /// [flat]: interest on the full amount for the whole term.
  /// Otherwise reducing balance (standard bank EMI formula).
  static double interest({
    required double principal,
    required double ratePercentPerYear,
    required int months,
    required bool flat,
  }) {
    if (principal <= 0 || ratePercentPerYear <= 0 || months <= 0) return 0;
    if (flat) {
      return (principal * (ratePercentPerYear / 100.0) * (months / 12.0)).roundToDouble();
    }
    final r = (ratePercentPerYear / 12.0) / 100.0;
    final pow = math.pow(1 + r, months);
    final emi = principal * r * pow / (pow - 1);
    return (emi * months - principal).clamp(0.0, double.infinity).roundToDouble();
  }

  /// GST on the processing fee and interest (GST does not apply to principal).
  static double gst({
    required double feeAndInterest,
    double percent = defaultGstPercent,
  }) {
    if (feeAndInterest <= 0) return 0;
    return (feeAndInterest * percent / 100.0).roundToDouble();
  }

  /// "I know the total": split [principal] (+ interest + [charges]) evenly.
  static EmiPlan fromTotal({
    required double principal,
    required int months,
    double ratePercentPerYear = 0,
    bool flat = false,
    double charges = 0,
  }) {
    if (principal <= 0 || months <= 0) return EmiPlan.empty;
    final interestAmount = interest(
      principal: principal,
      ratePercentPerYear: ratePercentPerYear,
      months: months,
      flat: flat,
    );
    final total = principal + interestAmount + charges;
    return EmiPlan(
      principal: principal,
      interest: interestAmount,
      charges: charges,
      totalPayable: total,
      monthly: _round2(total / months),
      months: months,
      chargesInsideEmi: true,
    );
  }

  /// "I know the monthly EMI": installments are exactly what was typed in.
  /// [principal] (optional) lets us show how much extra is being paid.
  /// [charges] are billed separately, not part of the EMI.
  static EmiPlan fromMonthly({
    required double monthly,
    required int months,
    double principal = 0,
    double charges = 0,
  }) {
    if (monthly <= 0 || months <= 0) return EmiPlan.empty;
    final total = _round2(monthly * months);
    return EmiPlan(
      principal: principal,
      interest: principal > 0 ? (total - principal).clamp(0.0, double.infinity) : 0,
      charges: charges,
      totalPayable: total,
      monthly: monthly,
      months: months,
      chargesInsideEmi: false,
    );
  }

  /// Yearly rate (reducing balance) implied by borrowing [principal] and
  /// repaying [monthly] × [months]. Null when it can't be meaningful
  /// (nothing extra is being paid, or inputs are missing).
  static double? impliedAnnualRate({
    required double principal,
    required double monthly,
    required int months,
  }) {
    if (principal <= 0 || monthly <= 0 || months <= 0) return null;
    if (monthly * months <= principal + 0.5) return null;

    double emiAt(double annualPercent) {
      final r = annualPercent / 1200.0;
      if (r == 0) return principal / months;
      final pow = math.pow(1 + r, months);
      return principal * r * pow / (pow - 1);
    }

    var lo = 0.0;
    var hi = 300.0;
    if (emiAt(hi) < monthly) return null;
    for (var i = 0; i < 80; i++) {
      final mid = (lo + hi) / 2;
      if (emiAt(mid) < monthly) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }
}
