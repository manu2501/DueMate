class LedgerSummary {
  final double totalGiven;
  final double totalReceived;
  final double totalOutstanding; // totalGiven - totalReceived
  final int activePeopleCount;
  final int settledPeopleCount;
  final int totalPeopleCount;

  const LedgerSummary({
    required this.totalGiven,
    required this.totalReceived,
    required this.totalOutstanding,
    required this.activePeopleCount,
    required this.settledPeopleCount,
    required this.totalPeopleCount,
  });

  static const empty = LedgerSummary(
    totalGiven: 0,
    totalReceived: 0,
    totalOutstanding: 0,
    activePeopleCount: 0,
    settledPeopleCount: 0,
    totalPeopleCount: 0,
  );
}

