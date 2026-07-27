class AppNotification {
  final int? id;
  final int? plantId;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final String? sourceTimestamp;

  const AppNotification({
    this.id,
    this.plantId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.sourceTimestamp,
  });

  factory AppNotification.fromMap(Map<String, Object?> map) {
    return AppNotification(
      id: map['id'] as int?,
      plantId: map['plantId'] as int?,
      title: map['title']?.toString() ?? 'Sensor alert',
      message: map['message']?.toString() ?? '',
      type: map['type']?.toString() ?? 'sensor',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead: (map['isRead'] as int? ?? 0) == 1,
      sourceTimestamp: map['sourceTimestamp']?.toString(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'plantId': plantId,
      'title': title,
      'message': message,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead ? 1 : 0,
      'sourceTimestamp': sourceTimestamp,
    };
  }
}
