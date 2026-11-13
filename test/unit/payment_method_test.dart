import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/data/database/tables.dart';

void main() {
  test('stored order is fixed: entries saved before Wallet keep their method', () {
    // The enum is persisted by index; new methods only ever go at the end.
    expect(PaymentMethod.values.map((m) => m.name),
        ['upi', 'cash', 'bankTransfer', 'card', 'other', 'wallet']);
  });

  test('pickers list every method once, with Other last', () {
    expect(PaymentMethodX.ordered, [
      PaymentMethod.upi,
      PaymentMethod.cash,
      PaymentMethod.bankTransfer,
      PaymentMethod.card,
      PaymentMethod.wallet,
      PaymentMethod.other,
    ]);
  });

  test('Wallet has its own label and icon', () {
    expect(PaymentMethod.wallet.label, 'Wallet');
    expect(PaymentMethodX.ordered.map((m) => m.icon).toSet(), hasLength(PaymentMethod.values.length));
  });
}
