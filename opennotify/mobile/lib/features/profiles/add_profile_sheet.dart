import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

Future<void> showAddProfileSheet(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Monitor a profile', style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Instagram username'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final username = controller.text.trim();
              if (username.isEmpty) return;
              try {
                await ref.read(apiClientProvider).request(
                  '/profiles',
                  method: 'POST',
                  body: {'username': username},
                );
                ref.invalidate(profilesProvider);
                ref.invalidate(dashboardStatsProvider);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              } catch (e) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Start monitoring'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}
