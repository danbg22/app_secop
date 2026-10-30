String? readSharedStorage(String key) => null;

void writeSharedStorage(String key, String value) {}

void broadcastRealtimePayload(String channelName, String jsonPayload) {}

void ensureRealtimeTabListener({
  required String channelName,
  required String storageKey,
  required void Function(String? payloadJson) onSyncEvent,
}) {}

