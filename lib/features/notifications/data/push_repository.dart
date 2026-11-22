import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/providers.dart';
import '../../../core/utils/web_push.dart';

/// Saves this browser's notification address for the signed-in person.
class PushRepository {
  PushRepository(this._client);

  final SupabaseClient _client;

  Future<void> save(PushSubscriptionData data) =>
      _client.rpc('save_push_subscription', params: {
        'p_endpoint': data.endpoint,
        'p_keys': data.keys,
        'p_user_agent': 'web',
      });

  Future<void> remove(String endpoint) =>
      _client.from('push_subscriptions').delete().eq('endpoint', endpoint);
}

final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => PushRepository(ref.watch(supabaseClientProvider)),
);
