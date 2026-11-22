// Browser notifications through the small script in web/push.js.
import 'dart:convert';
import 'dart:js_interop';

extension type _RhPush._(JSObject _) implements JSObject {
  external JSString permission();
  external JSPromise<JSString> subscribe(JSString publicKey);
  external JSPromise<JSString> current();
  external JSPromise<JSString> unsubscribe();
}

@JS('rhPush')
external _RhPush? get _push;

class PushSubscriptionData {
  const PushSubscriptionData({required this.endpoint, required this.keys});

  final String endpoint;
  final Map<String, dynamic> keys;
}

/// What the browser says about notifications right now.
class PushStatus {
  const PushStatus({required this.permission, required this.subscription});

  /// 'unsupported', 'default' (not asked yet), 'granted' or 'denied'.
  final String permission;
  final PushSubscriptionData? subscription;

  bool get supported => permission != 'unsupported';
  bool get denied => permission == 'denied';
  bool get enabled => permission == 'granted' && subscription != null;
}

PushSubscriptionData? _parse(String raw) {
  if (raw.isEmpty || !raw.startsWith('{')) return null;
  try {
    final json = jsonDecode(raw);
    if (json is! Map) return null;
    final endpoint = json['endpoint'];
    final keys = json['keys'];
    if (endpoint is! String || keys is! Map) return null;
    return PushSubscriptionData(
      endpoint: endpoint,
      keys: Map<String, dynamic>.from(keys),
    );
  } catch (_) {
    return null;
  }
}

Future<PushStatus> readPushStatus() async {
  final push = _push;
  if (push == null) {
    return const PushStatus(permission: 'unsupported', subscription: null);
  }
  try {
    final permission = push.permission().toDart;
    final raw = (await push.current().toDart).toDart;
    return PushStatus(permission: permission, subscription: _parse(raw));
  } catch (_) {
    return const PushStatus(permission: 'unsupported', subscription: null);
  }
}

/// Asks the browser for permission and subscribes. Call it straight from a
/// button tap. Returns the subscription, or a short reason it failed:
/// 'unsupported', 'denied' or 'error'.
Future<({PushSubscriptionData? data, String? problem})> enablePush(
  String publicKey,
) async {
  final push = _push;
  if (push == null) return (data: null, problem: 'unsupported');
  try {
    final raw = (await push.subscribe(publicKey.toJS).toDart).toDart;
    final data = _parse(raw);
    if (data != null) return (data: data, problem: null);
    return (data: null, problem: raw.isEmpty ? 'error' : raw);
  } catch (_) {
    return (data: null, problem: 'error');
  }
}

/// Turns notifications off in this browser. Returns the old endpoint.
Future<String?> disablePush() async {
  final push = _push;
  if (push == null) return null;
  try {
    final endpoint = (await push.unsubscribe().toDart).toDart;
    return endpoint.isEmpty ? null : endpoint;
  } catch (_) {
    return null;
  }
}
