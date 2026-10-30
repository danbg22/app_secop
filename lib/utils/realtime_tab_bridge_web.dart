// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

html.BroadcastChannel? _activeBroadcastChannel;
bool _listenersRegistered = false;

String? readSharedStorage(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void writeSharedStorage(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

void broadcastRealtimePayload(String channelName, String jsonPayload) {
  try {
    final ch = html.BroadcastChannel(channelName);
    ch.postMessage(jsonPayload);
    ch.close();
  } catch (_) {}
}

void ensureRealtimeTabListener({
  required String channelName,
  required String storageKey,
  required void Function(String? payloadJson) onSyncEvent,
}) {
  if (_listenersRegistered) return;
  _listenersRegistered = true;

  try {
    _activeBroadcastChannel = html.BroadcastChannel(channelName);
    _activeBroadcastChannel!.onMessage.listen((html.MessageEvent event) {
      final data = event.data;
      if (data is String && data.isNotEmpty) {
        onSyncEvent(data);
      } else {
        onSyncEvent(null);
      }
    });
  } catch (_) {}

  try {
    html.window.onStorage.listen((html.StorageEvent event) {
      if (event.key == null ||
          event.key == storageKey ||
          event.key == 'flutter.$storageKey') {
        onSyncEvent(null);
      }
    });
  } catch (_) {}

  try {
    html.window.onFocus.listen((_) => onSyncEvent(null));
    html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'visible') {
        onSyncEvent(null);
      }
    });
  } catch (_) {}
}

