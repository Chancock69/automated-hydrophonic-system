enum PlantHarvestType {
  single('Single harvest'),
  multiple('Multiple harvest');

  final String label;

  const PlantHarvestType(this.label);

  static PlantHarvestType fromDb(String? value) {
    return PlantHarvestType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => PlantHarvestType.single,
    );
  }
}

class PlantModel {
  final int? id;
  final String name;
  final String description;
  final String? imagePath;
  final DateTime addedDate;
  final DateTime? harvestDate;
  final DateTime? actualHarvestDate;
  final int quantity;
  final PlantHarvestType harvestType;
  final double totalHarvestWeight;
  final int harvestCount;
  final bool isActive;
  final bool isHarvested;

  const PlantModel({
    this.id,
    required this.name,
    required this.description,
    this.imagePath,
    required this.addedDate,
    this.harvestDate,
    this.actualHarvestDate,
    this.quantity = 1,
    this.harvestType = PlantHarvestType.single,
    this.totalHarvestWeight = 0,
    this.harvestCount = 0,
    this.isActive = false,
    this.isHarvested = false,
  });

  PlantModel copyWith({
    int? id,
    String? name,
    String? description,
    String? imagePath,
    DateTime? addedDate,
    DateTime? harvestDate,
    DateTime? actualHarvestDate,
    int? quantity,
    PlantHarvestType? harvestType,
    double? totalHarvestWeight,
    int? harvestCount,
    bool? isActive,
    bool? isHarvested,
  }) => PlantModel(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    imagePath: imagePath ?? this.imagePath,
    addedDate: addedDate ?? this.addedDate,
    harvestDate: harvestDate ?? this.harvestDate,
    actualHarvestDate: actualHarvestDate ?? this.actualHarvestDate,
    quantity: quantity ?? this.quantity,
    harvestType: harvestType ?? this.harvestType,
    totalHarvestWeight: totalHarvestWeight ?? this.totalHarvestWeight,
    harvestCount: harvestCount ?? this.harvestCount,
    isActive: isActive ?? this.isActive,
    isHarvested: isHarvested ?? this.isHarvested,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'description': description,
    'imagePath': imagePath,
    'addedDate': addedDate.toIso8601String(),
    'harvestDate': harvestDate?.toIso8601String(),
    'actualHarvestDate': actualHarvestDate?.toIso8601String(),
    'quantity': quantity.clamp(1, 6),
    'plantType': harvestType.name,
    'totalHarvestWeight': totalHarvestWeight,
    'harvestCount': harvestCount,
    'isActive': isActive ? 1 : 0,
    'isHarvested': isHarvested ? 1 : 0,
  };

  factory PlantModel.fromMap(Map<String, dynamic> m) => PlantModel(
    id: m['id'] as int?,
    name: m['name'] as String,
    description: m['description'] as String,
    imagePath: m['imagePath'] as String?,
    addedDate: DateTime.parse(m['addedDate'] as String),
    harvestDate: m['harvestDate'] != null
        ? DateTime.parse(m['harvestDate'] as String)
        : null,
    actualHarvestDate: m['actualHarvestDate'] != null
        ? DateTime.parse(m['actualHarvestDate'] as String)
        : null,
    quantity: ((m['quantity'] as int?) ?? 1).clamp(1, 6),
    harvestType: PlantHarvestType.fromDb(m['plantType'] as String?),
    totalHarvestWeight: ((m['totalHarvestWeight'] as num?) ?? 0).toDouble(),
    harvestCount: (m['harvestCount'] as int?) ?? 0,
    isActive: (m['isActive'] as int) == 1,
    isHarvested: (m['isHarvested'] as int) == 1,
  );
}
