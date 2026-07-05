import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import 'add_profile_sheet.dart';
import 'status_chip.dart';

final _dateFormat = DateFormat.yMMMd().add_Hm();

String formatDate(DateTime? value) =>
    value == null ? '—' : _dateFormat.format(value.toLocal());

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Monitored profiles')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddProfileSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(profilesProvider.future),
        child: profiles.when(
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
                    Icon(Icons.people_outline, size: 48),
                    SizedBox(height: 12),
                    Center(child: Text('Nothing monitored yet')),
                    Center(
                      child: Text(
                        'Tap + to add an Instagram username.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _ProfileTile(profile: items[index]),
                ),
        ),
      ),
    );
  }
}

class _ProfileTile extends ConsumerWidget {
  const _ProfileTile({required this.profile});

  final MonitoredProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiClientProvider);

    Future<void> run(Future<dynamic> future) async {
      try {
        await future;
        ref.invalidate(profilesProvider);
        ref.invalidate(dashboardStatsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => context.go(
          '/profiles/${profile.id}?username=${profile.username}',
        ),
        title: Text('@${profile.username}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Checked ${formatDate(profile.lastCheckedAt)}\n'
            '${profile.monitoringEnabled ? 'Monitoring on' : 'Paused'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusChip(status: profile.currentStatus),
            PopupMenuButton<String>(
              onSelected: (action) => switch (action) {
                'toggle' => run(api.request(
                    '/profiles/${profile.id}/${profile.monitoringEnabled ? 'pause' : 'resume'}',
                    method: 'PATCH',
                  )),
                'delete' =>
                  run(api.request('/profiles/${profile.id}', method: 'DELETE')),
                _ => null,
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(profile.monitoringEnabled ? 'Pause' : 'Resume'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
