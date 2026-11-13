import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/display_money.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/person_summary.dart';
import 'package:duemate/domain/loan_dues.dart';

/// Layout used by every top-level tab: a large title that collapses on
/// scroll, optional actions, then the page content as slivers.
class TabScaffold extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;

  const TabScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
    this.floatingActionButton,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      slivers: [
        SliverAppBar.medium(
          title: Text(title),
          actions: [...actions, const SizedBox(width: AppSpace.xs)],
        ),
        ...slivers,
        // Room for the FAB / last row above the navigation bar.
        SliverToBoxAdapter(child: SizedBox(height: floatingActionButton == null ? AppSpace.xl : 96)),
      ],
    );
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: onRefresh == null ? scroll : RefreshIndicator(onRefresh: onRefresh!, child: scroll),
    );
  }
}

/// Section title with an optional trailing action ("See all").
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.xl, AppSpace.sm, AppSpace.sm),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!))
          else
            const SizedBox(height: 48),
        ],
      ),
    );
  }
}

/// Rows that belong together, on one surface, separated by hairlines.
/// Prefer this over a card per item.
class GroupCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  /// Indent of the dividers (aligns with row text, past the leading avatar).
  final double dividerIndent;

  const GroupCard({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpace.lg),
    this.dividerIndent = 72,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: margin,
      child: Material(
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(indent: dividerIndent),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

enum MoneyTone { neutral, positive, negative, muted }

/// A formatted amount with an explicit sign and a colour that follows the
/// app's money rules (see [LedgerColors]).
class MoneyText extends ConsumerWidget {
  final double amount;
  final String symbol;
  final MoneyTone tone;

  /// '+', '−' or '' prefix. Defaults to none.
  final String sign;
  final TextStyle? style;
  final TextAlign? textAlign;

  const MoneyText(
    this.amount, {
    super.key,
    required this.symbol,
    this.tone = MoneyTone.neutral,
    this.sign = '',
    this.style,
    this.textAlign,
  });

  static Color colorFor(BuildContext context, MoneyTone tone) {
    final ledger = LedgerColors.of(context);
    final cs = Theme.of(context).colorScheme;
    return switch (tone) {
      MoneyTone.positive => ledger.owedToYou,
      MoneyTone.negative => ledger.youOwe,
      MoneyTone.muted => cs.onSurfaceVariant,
      MoneyTone.neutral => cs.onSurface,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = style ?? Theme.of(context).textTheme.titleSmall;
    final hidden = ref.watch(hideBalancesProvider);
    return Text(
      hidden ? '$symbol${DisplayMoney.mask}' : '$sign${CurrencyFormatter.format(amount.abs(), symbol: symbol)}',
      semanticsLabel: hidden ? DisplayMoney.hiddenLabel : null,
      textAlign: textAlign,
      maxLines: 1,
      style: base?.copyWith(color: colorFor(context, tone)),
    );
  }
}

/// Balance wording used everywhere a person's balance is shown.
({String label, MoneyTone tone}) balanceWording(PersonSummary s) {
  if (s.owesMoney) return (label: 'owes you', tone: MoneyTone.positive);
  if (s.isOverpaid) return (label: 'you owe', tone: MoneyTone.negative);
  return (label: 'settled', tone: MoneyTone.muted);
}

/// How much has been paid back, as a thin bar and "Paid ₹X of ₹Y · N%".
/// The paid part is green when it's money coming back to you and neutral
/// ink when you're the one repaying (lending is never red). Amounts follow
/// "Hide amounts"; the percentage stays visible.
class RepaymentBar extends ConsumerWidget {
  final Repayment repayment;
  final double thickness;

  const RepaymentBar(this.repayment, {super.key, this.thickness = 4});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ledger = LedgerColors.of(context);
    final money = ref.watch(displayMoneyProvider);
    final r = repayment;
    final caption =
        '${r.byYou ? 'You paid back' : 'Paid'} ${money(r.paid)} of ${money(r.of)} · ${r.percent}%';

    return Semantics(
      label: caption,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: r.fraction,
            minHeight: thickness,
            borderRadius: BorderRadius.circular(thickness),
            color: r.byYou ? ledger.cashOut : ledger.cashIn,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// "₹5,000 due back by 15 Dec" or, once the date has passed, "₹5,000
/// overdue since 15 Dec" in the warning colour with an icon (overdue money is
/// owed *to* you, so it's never red). Amounts follow "Hide amounts".
class DueBackLine extends ConsumerWidget {
  final LoanDueStatus status;
  final TextStyle? style;

  const DueBackLine(this.status, {super.key, this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final money = ref.watch(displayMoneyProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = status.isOverdue(today);
    final next = status.next;
    final days = next.date.difference(today).inDays;
    final when = days == 0
        ? 'today'
        : days == 1
            ? 'tomorrow'
            : 'by ${DateFormatter.formatShortDate(next.date)}';
    final text = overdue
        ? '${money(status.overdueAmount(today))} overdue since ${DateFormatter.formatShortDate(next.date)}'
        : '${money(next.amount)} due back $when';
    final color = overdue ? cs.tertiary : cs.onSurfaceVariant;
    final base = style ?? Theme.of(context).textTheme.bodySmall;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(overdue ? Icons.error_outline_rounded : Icons.schedule_rounded, size: (base?.fontSize ?? 12) + 2, color: color),
        const SizedBox(width: AppSpace.xs),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: base?.copyWith(color: color, fontWeight: overdue ? FontWeight.w600 : null)),
        ),
      ],
    );
  }
}

/// One person in a list: who, when you last dealt with them, and the balance.
/// With [showRepayment], also how much has been paid back.
class PersonRow extends StatelessWidget {
  final PersonSummary summary;
  final String symbol;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showRepayment;

  /// Dated loans not yet repaid: replaces "last activity" with when it's due.
  final LoanDueStatus? due;

  const PersonRow({
    super.key,
    required this.summary,
    required this.symbol,
    this.onTap,
    this.onLongPress,
    this.showRepayment = false,
    this.due,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = summary.person;
    final wording = balanceWording(summary);
    final last = summary.lastTransaction?.transactionDate;
    final subtitle = last != null
        ? 'Last activity ${DateFormatter.formatRelative(last)}'
        : (p.phone?.isNotEmpty ?? false)
            ? p.phone!
            : 'No entries yet';
    final repayment = showRepayment ? summary.repayment : null;
    final open = onTap ?? () => context.push('/people/${p.id}');

    final tile = ListTile(
      onTap: repayment == null ? open : null,
      onLongPress: repayment == null ? onLongPress : null,
      leading: AvatarWidget(name: p.name, radius: 20, heroTag: 'avatar-${p.id}'),
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: due != null ? DueBackLine(due!) : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (summary.balance.abs() > 0.0001)
            MoneyText(summary.balance, symbol: symbol, tone: wording.tone),
          Text(
            wording.label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
    if (repayment == null) return tile;

    // The bar spans the row under the name and balance, so every row's bar
    // has the same width whatever the balance column needs. One tap target.
    return InkWell(
      onTap: open,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tile,
          Padding(
            // Lines up with the name and the balance: tile padding, then the
            // 40dp avatar and ListTile's 16dp gap.
            padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter + 40 + 16, 0, AppSpace.screenGutter, AppSpace.md),
            child: RepaymentBar(repayment),
          ),
        ],
      ),
    );
  }
}

/// "Today", "Yesterday", "Mon, 9 Nov" style header for date-grouped lists.
class DateHeader extends StatelessWidget {
  final DateTime date;
  final Widget? trailing;

  const DateHeader(this.date, {super.key, this.trailing});

  static String label(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return DateFormatter.formatRelative(d);
    return DateFormatter.formatDate(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.lg, AppSpace.screenGutter, AppSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label(date),
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small rounded square holding an icon; used as a row's leading visual.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;

  const IconBadge(this.icon, {super.key, this.color, this.background, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, size: size * 0.5, color: color ?? cs.onSurfaceVariant),
    );
  }
}

/// App-bar menu for picking a year, e.g. on trend screens.
class YearMenuButton extends StatelessWidget {
  final int year;
  final List<int> years;
  final ValueChanged<int> onSelected;

  const YearMenuButton({super.key, required this.year, required this.years, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Choose year',
      initialValue: year,
      onSelected: onSelected,
      itemBuilder: (_) => [for (final y in years.reversed) PopupMenuItem(value: y, child: Text('$y'))],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        child: Row(
          children: [
            Text('$year', style: Theme.of(context).textTheme.titleMedium),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}

/// How reliably someone repays loans with a "return by" date, e.g.
/// "Repaid on time: 3 of 4 loans (75%)". Neutral ink: it's a record, not money
/// owed. Shows nothing until at least one dated loan has been paid back:
/// a loan that is only overdue so far is already on the due-back line.
class RepaymentRecordLine extends StatelessWidget {
  final RepaymentRecord record;
  final TextStyle? style;

  const RepaymentRecordLine(this.record, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final share = record.onTimeShare;
    if (share == null || record.repaid == 0) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final base = style ?? Theme.of(context).textTheme.bodySmall;
    final loans = record.judged == 1 ? 'loan' : 'loans';
    final text = 'Repaid on time: ${record.onTime} of ${record.judged} $loans (${(share * 100).round()}%)';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_available_outlined, size: (base?.fontSize ?? 12) + 2, color: color),
        const SizedBox(width: AppSpace.xs),
        Flexible(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: base?.copyWith(color: color)),
        ),
      ],
    );
  }
}
