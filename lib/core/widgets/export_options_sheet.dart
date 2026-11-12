import 'package:flutter/material.dart';

class ExportOptionsSheet {
  static void show({
    required BuildContext context,
    required String title,
    required VoidCallback onSharePdf,
    required VoidCallback onShareCsv,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: cs.surfaceContainer,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.picture_as_pdf_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 22),
                  ),
                  title: const Text('Share as PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('A formatted statement', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onSharePdf();
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: cs.surfaceContainer,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.table_chart_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 22),
                  ),
                  title: const Text('Export as CSV', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Opens in Excel or Google Sheets', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onShareCsv();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

