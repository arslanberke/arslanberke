import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../profiles/add_profile_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddProfileSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add profile'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardStatsProvider.future),
        child: stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(child: Text('$error')),
            ],
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _StatCard(
                    label: 'Active profiles',
                    value: '${data.activeProfiles}',
                    icon: Icons.people_outline,
                  ),
                  _StatCard(
                    label: 'Changes detected',
                    value: '${data.changesDetected}',
                    icon: Icons.timeline,
                  ),
                  _StatCard(
                    label: 'Notifications sent',
                    value: '${data.notificationsSent}',
                    icon: Icons.notifications_outlined,
                  ),
                  _StatCard(
                    label: 'Plan',
                    value: data.plan,
                    icon: Icons.credit_card,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: accentGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
