import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/domain/entities/person_summary.dart';

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
class MoneyText extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleSmall;
    return Text(
      '$sign${CurrencyFormatter.format(amount.abs(), symbol: symbol)}',
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

/// One person in a list: who, when you last dealt with them, and the balance.
class PersonRow extends StatelessWidget {
  final PersonSummary summary;
  final String symbol;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PersonRow({
    super.key,
    required this.summary,
    required this.symbol,
    this.onTap,
    this.onLongPress,
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

    return ListTile(
      onTap: onTap ?? () => context.push('/people/${p.id}'),
      onLongPress: onLongPress,
      leading: AvatarWidget(name: p.name, radius: 20, heroTag: 'avatar-${p.id}'),
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
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
