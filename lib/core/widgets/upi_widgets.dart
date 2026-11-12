import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/upi.dart';

// QR codes must be dark modules on a light background to scan reliably
// (many scanners can't read inverted codes), so these two colours stay fixed
// in both themes. This is the one deliberate exception to theme colours.
const _qrInk = Color(0xFF000000);
const _qrPaper = Color(0xFFFFFFFF);
const _qrEye = QrEyeStyle(eyeShape: QrEyeShape.square, color: _qrInk);
const _qrModules = QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _qrInk);

/// Asks for your UPI ID and the name payers see. Returns true when a valid
/// ID is saved.
Future<bool> editUpiProfile(BuildContext context, WidgetRef ref) async {
  final current = ref.read(upiProfileProvider);
  final saved = await showDialog<UpiProfile>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _UpiProfileDialog(initial: current),
  );
  if (saved == null) return false;
  await ref.read(upiProfileProvider.notifier).set(id: saved.id, name: saved.name);
  return saved.isSet;
}

class _UpiProfileDialog extends StatefulWidget {
  final UpiProfile initial;
  const _UpiProfileDialog({required this.initial});

  @override
  State<_UpiProfileDialog> createState() => _UpiProfileDialogState();
}

class _UpiProfileDialogState extends State<_UpiProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _id = TextEditingController(text: widget.initial.id ?? '');
  late final _name = TextEditingController(text: widget.initial.name ?? '');

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your UPI ID'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _id,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'UPI ID', hintText: 'name@okhdfcbank'),
              validator: Upi.validateOptionalId,
            ),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                helperText: 'Shown to the person paying you',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(UpiProfile(id: _id.text.trim(), name: _name.text.trim()));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Hands a `upi://pay` link to a UPI app; true if one opened. Overridden in
/// tests (there's no UPI app there).
final upiLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  },
);

/// Opens a UPI app to pay [payeeId], pre-filled with [amount]. Returns true
/// if one opened. The payment itself happens in that app; UPI apps don't
/// report back, so the caller asks the user afterwards.
Future<bool> payWithUpiApp(
  BuildContext context,
  WidgetRef ref, {
  required String payeeId,
  required String payeeName,
  required double amount,
  String? note,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final uri = Upi.payUri(payeeId: payeeId, payeeName: payeeName, amount: amount, note: note);
  final opened = await ref.read(upiLauncherProvider)(uri);
  if (!opened) {
    messenger?.showSnackBar(const SnackBar(content: Text('No UPI app found on this phone.')));
  }
  return opened;
}

/// Shows a UPI QR for you to be paid [amount] (optional). Asks for your UPI
/// ID first if it isn't set yet.
class UpiQrSheet extends ConsumerWidget {
  final double? amount;
  final String? note;

  const UpiQrSheet({super.key, this.amount, this.note});

  static Future<void> show(BuildContext context, WidgetRef ref, {double? amount, String? note}) async {
    if (!ref.read(upiProfileProvider).isSet) {
      final ok = await editUpiProfile(context, ref);
      if (!ok || !context.mounted) return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => UpiQrSheet(amount: amount, note: note),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profile = ref.watch(upiProfileProvider);
    final id = profile.id;
    if (id == null) return const SizedBox.shrink();

    final payAmount = (amount ?? 0) > 0 ? amount : null;
    final uri = Upi.payUri(payeeId: id, payeeName: profile.name, amount: payAmount, note: note);
    final amountText = payAmount == null ? null : CurrencyFormatter.format(payAmount, symbol: Upi.currencySymbol);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Scan to pay', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.xs),
            Text(
              amountText ?? 'They enter the amount',
              style: amountText == null
                  ? theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)
                  : theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.lg),
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(
                  color: _qrPaper,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: QrImageView(
                  data: uri.toString(),
                  size: 232,
                  padding: EdgeInsets.zero,
                  backgroundColor: _qrPaper,
                  eyeStyle: _qrEye,
                  dataModuleStyle: _qrModules,
                  semanticsLabel: 'UPI QR code for $id',
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            if (profile.name != null)
              Text(profile.name!, style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
            SelectableText(id, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.md),
            Text(
              'Any UPI app can scan this. Record the payment once it reaches you.',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => editUpiProfile(context, ref),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Change ID'),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _share(context, uri, id, profile.name, amountText),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shares the QR as a PNG plus the UPI ID in text, so it works whether the
  /// other person scans it from another phone or saves the image.
  static Future<void> _share(BuildContext context, Uri uri, String id, String? name, String? amountText) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final text = [
      if (amountText != null) 'Please pay $amountText',
      'UPI ID: $id${name == null ? '' : ' ($name)'}',
    ].join('\n');
    try {
      final file = await _qrPng(uri.toString());
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: text));
    } catch (_) {
      messenger?.showSnackBar(const SnackBar(content: Text("Couldn't share the QR code.")));
    }
  }

  static Future<File> _qrPng(String data) async {
    const qrSize = 720.0;
    const margin = 80.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, qrSize + margin * 2, qrSize + margin * 2), Paint()..color = _qrPaper);
    canvas.translate(margin, margin);
    QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: _qrEye,
      dataModuleStyle: _qrModules,
    ).paint(canvas, const Size.square(qrSize));
    final image = await recorder.endRecording().toImage((qrSize + margin * 2).toInt(), (qrSize + margin * 2).toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/duemate_upi_qr.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    return file;
  }
}
