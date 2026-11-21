import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/providers.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.courseId,
    required this.sessionId,
    required this.createdAt,
    required this.readAt,
  });

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    final data = row['data'];
    return AppNotification(
      id: row['id'] as String,
      type: (row['type'] as String?) ?? '',
      title: (row['title'] as String?) ?? '',
      body: row['body'] as String?,
      courseId: data is Map ? data['course_id'] as String? : null,
      sessionId: data is Map ? data['session_id'] as String? : null,
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
      readAt: DateTime.tryParse((row['read_at'] as String?) ?? ''),
    );
  }

  final String id;
  final String type;
  final String title;
  final String? body;
  final String? courseId;
  final String? sessionId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;
}

class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  Future<List<AppNotification>> list() async {
    final rows = await _client
        .from('notifications')
        .select('id, type, title, body, data, read_at, created_at')
        .order('created_at', ascending: false)
        .limit(80);
    return [
      for (final r in rows as List)
        AppNotification.fromRow(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<void> markRead(String id) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> markAllRead() async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .filter('read_at', 'is', null);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(supabaseClientProvider)),
);

final notificationsLiveProvider = StreamProvider.autoDispose<int>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<int>();
  var ticks = 0;
  final channel = client.channel('notifications-live');
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'notifications',
    callback: (payload) {
      if (!controller.isClosed) controller.add(++ticks);
    },
  );
  channel.subscribe();
  ref.onDispose(() {
    client.removeChannel(channel);
    controller.close();
  });
  return controller.stream;
});

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) {
  ref.watch(notificationsLiveProvider);
  return ref.watch(notificationRepositoryProvider).list();
});

/// How many alerts are unread (shown as a badge on the Alerts tab).
final unreadCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(notificationsProvider).value;
  if (items == null) return 0;
  return items.where((n) => n.unread).length;
});
