class HarvestEvent {
  final int? id;
  final int plantId;
  final String plantName;
  final DateTime harvestedAt;
  final double weightKg;
  final int survivedCount;
  final int totalCount;
  final double lifeRate;
  final bool markedDone;

  const HarvestEvent({
    this.id,
    required this.plantId,
    required this.plantName,
    required this.harvestedAt,
    required this.weightKg,
    required this.survivedCount,
    required this.totalCount,
    required this.lifeRate,
    required this.markedDone,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'plantId': plantId,
    'plantName': plantName,
    'harvestedAt': harvestedAt.toIso8601String(),
    'weightKg': weightKg,
    'survivedCount': survivedCount,
    'totalCount': totalCount,
    'lifeRate': lifeRate,
    'markedDone': markedDone ? 1 : 0,
  };

  factory HarvestEvent.fromMap(Map<String, dynamic> map) => HarvestEvent(
    id: map['id'] as int?,
    plantId: map['plantId'] as int,
    plantName: map['plantName'] as String,
    harvestedAt: DateTime.parse(map['harvestedAt'] as String),
    weightKg: ((map['weightKg'] as num?) ?? 0).toDouble(),
    survivedCount: (map['survivedCount'] as int?) ?? 0,
    totalCount: (map['totalCount'] as int?) ?? 0,
    lifeRate: ((map['lifeRate'] as num?) ?? 0).toDouble(),
    markedDone: ((map['markedDone'] as int?) ?? 0) == 1,
  );
}
