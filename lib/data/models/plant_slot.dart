enum PlantSlotStatus {
  empty('Empty'),
  alive('Alive'),
  dead('Dead');

  final String label;

  const PlantSlotStatus(this.label);

  static PlantSlotStatus fromDb(String? value) {
    return PlantSlotStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PlantSlotStatus.empty,
    );
  }
}

class PlantSlot {
  final int plantId;
  final int position;
  final PlantSlotStatus status;
  final DateTime updatedAt;

  const PlantSlot({
    required this.plantId,
    required this.position,
    required this.status,
    required this.updatedAt,
  });

  bool get isPlanted => status != PlantSlotStatus.empty;

  Map<String, dynamic> toMap() => {
    'plantId': plantId,
    'position': position,
    'status': status.name,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PlantSlot.fromMap(Map<String, dynamic> map) => PlantSlot(
    plantId: map['plantId'] as int,
    position: map['position'] as int,
    status: PlantSlotStatus.fromDb(map['status'] as String?),
    updatedAt:
        DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
  );
}
