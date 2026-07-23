enum ProfileStatus { public, private, unknown }

ProfileStatus statusFromApi(String value) => switch (value) {
      'PUBLIC' => ProfileStatus.public,
      'PRIVATE' => ProfileStatus.private,
      _ => ProfileStatus.unknown,
    };

class MonitoredProfile {
  final String id;
  final String username;
  final ProfileStatus currentStatus;
  final bool monitoringEnabled;
  final DateTime? lastCheckedAt;
  final DateTime? lastChangedAt;

  const MonitoredProfile({
    required this.id,
    required this.username,
    required this.currentStatus,
    required this.monitoringEnabled,
    this.lastCheckedAt,
    this.lastChangedAt,
  });

  factory MonitoredProfile.fromJson(Map<String, dynamic> json) => MonitoredProfile(
        id: json['id'] as String,
        username: json['username'] as String,
        currentStatus: statusFromApi(json['currentStatus'] as String),
        monitoringEnabled: json['monitoringEnabled'] as bool,
        lastCheckedAt: json['lastCheckedAt'] != null
            ? DateTime.parse(json['lastCheckedAt'] as String)
            : null,
        lastChangedAt: json['lastChangedAt'] != null
            ? DateTime.parse(json['lastChangedAt'] as String)
            : null,
      );
}

class StatusChange {
  final String id;
  final ProfileStatus oldStatus;
  final ProfileStatus newStatus;
  final DateTime createdAt;

  const StatusChange({
    required this.id,
    required this.oldStatus,
    required this.newStatus,
    required this.createdAt,
  });

  factory StatusChange.fromJson(Map<String, dynamic> json) => StatusChange(
        id: json['id'] as String,
        oldStatus: statusFromApi(json['oldStatus'] as String),
        newStatus: statusFromApi(json['newStatus'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String channel;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.channel,
    required this.createdAt,
    required this.read,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        channel: json['channel'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        read: json['readAt'] != null,
      );
}

class DashboardStats {
  final int activeProfiles;
  final int changesDetected;
  final int notificationsSent;
  final String plan;

  const DashboardStats({
    required this.activeProfiles,
    required this.changesDetected,
    required this.notificationsSent,
    required this.plan,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        activeProfiles: json['activeProfiles'] as int,
        changesDetected: json['changesDetected'] as int,
        notificationsSent: json['notificationsSent'] as int,
        plan: (json['subscription'] as Map<String, dynamic>)['plan'] as String,
      );
}
