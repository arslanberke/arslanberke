import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'profiles_screen.dart' show formatDate;
import 'status_chip.dart';

class ProfileDetailScreen extends ConsumerWidget {
  const ProfileDetailScreen({super.key, required this.id, required this.username});

  final String id;
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(profileHistoryProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text('@$username')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (changes) => changes.isEmpty
            ? const Center(child: Text('No status changes recorded yet'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: changes.length,
                itemBuilder: (context, index) {
                  final change = changes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Row(
                        children: [
                          StatusChip(status: change.oldStatus),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward, size: 14),
                          ),
                          StatusChip(status: change.newStatus),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(formatDate(change.createdAt)),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
