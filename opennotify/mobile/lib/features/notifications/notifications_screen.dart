import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../profiles/profiles_screen.dart' show formatDate;

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all read',
            onPressed: () async {
              await ref
                  .read(apiClientProvider)
                  .request('/notifications/read-all', method: 'PATCH');
              ref.invalidate(notificationsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(notificationsProvider.future),
        child: notifications.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(child: Text('$error')),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Icon(Icons.notifications_none, size: 48),
                    SizedBox(height: 12),
                    Center(child: Text('No notifications yet')),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          item.read
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: item.read ? null : Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(item.title),
                        subtitle: Text('${item.body}\n${formatDate(item.createdAt)}'),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
