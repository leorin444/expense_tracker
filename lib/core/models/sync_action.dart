class SyncAction {
  final String id;
  final String collection; // 'expenses', 'categories', 'finance'
  final String action; // 'CREATE', 'UPDATE', 'DELETE'
  final String payload; // JSON string of the object data
  final int timestamp;

  SyncAction({
    required this.id,
    required this.collection,
    required this.action,
    required this.payload,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collection': collection,
      'action': action,
      'payload': payload,
      'timestamp': timestamp,
    };
  }

  factory SyncAction.fromMap(Map<String, dynamic> map) {
    return SyncAction(
      id: map['id'] as String,
      collection: map['collection'] as String,
      action: map['action'] as String,
      payload: map['payload'] as String,
      timestamp: map['timestamp'] as int?,
    );
  }
}
