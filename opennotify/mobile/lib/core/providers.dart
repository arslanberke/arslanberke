import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final api = ref.read(apiClientProvider);
    return await api.accessToken != null;
  }

  Future<void> login(String email, String password) async {
    final api = ref.read(apiClientProvider);
    final pair = await api.request(
      '/auth/login',
      method: 'POST',
      body: {'email': email, 'password': password},
    ) as Map<String, dynamic>;
    await api.saveTokens(pair);
    state = const AsyncData(true);
  }

  Future<void> register(String name, String email, String password) async {
    final api = ref.read(apiClientProvider);
    final pair = await api.request(
      '/auth/register',
      method: 'POST',
      body: {'name': name, 'email': email, 'password': password},
    ) as Map<String, dynamic>;
    await api.saveTokens(pair);
    state = const AsyncData(true);
  }

  Future<void> logout() async {
    await ref.read(apiClientProvider).clearTokens();
    state = const AsyncData(false);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final data = await ref.read(apiClientProvider).request('/dashboard/stats');
  return DashboardStats.fromJson(data as Map<String, dynamic>);
});

final profilesProvider = FutureProvider<List<MonitoredProfile>>((ref) async {
  final data = await ref.read(apiClientProvider).request('/profiles') as List<dynamic>;
  return data
      .map((json) => MonitoredProfile.fromJson(json as Map<String, dynamic>))
      .toList();
});

final profileHistoryProvider =
    FutureProvider.family<List<StatusChange>, String>((ref, id) async {
  final data =
      await ref.read(apiClientProvider).request('/profiles/$id/history') as List<dynamic>;
  return data.map((json) => StatusChange.fromJson(json as Map<String, dynamic>)).toList();
});

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final data = await ref.read(apiClientProvider).request('/notifications') as List<dynamic>;
  return data
      .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
      .toList();
});
