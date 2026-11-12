import 'package:flutter/material.dart';
import 'package:duemate/core/widgets/choice_tile_group.dart';

enum EmiType {
  creditCard,
  loan;

  /// Value stored in the database `kind` column.
  String get kind => this == EmiType.loan ? 'loan' : 'card';
}

class EmiTypeSelector extends StatelessWidget {
  final EmiType selectedType;
  final ValueChanged<EmiType> onChanged;

  const EmiTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceTileGroup<EmiType>(
      selected: selectedType,
      onChanged: onChanged,
      options: const [
        ChoiceOption(
          value: EmiType.creditCard,
          label: 'Card EMI',
          subtitle: 'A purchase on a card',
          icon: Icons.credit_card_rounded,
        ),
        ChoiceOption(
          value: EmiType.loan,
          label: 'Loan',
          subtitle: 'Cash or bank loan',
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }
}
