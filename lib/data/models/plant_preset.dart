class SensorRange {
  final double min;
  final double max;

  const SensorRange(this.min, this.max);

  bool contains(double value) => value >= min && value <= max;
}

class PlantPreset {
  final String key;
  final String label;
  final String description;
  final int daysToHarvest;
  final SensorRange ph;
  final SensorRange tds;
  final SensorRange temperature;
  final SensorRange humidity;

  const PlantPreset({
    required this.key,
    required this.label,
    required this.description,
    required this.daysToHarvest,
    required this.ph,
    required this.tds,
    required this.temperature,
    required this.humidity,
  });

  static const custom = PlantPreset(
    key: 'custom',
    label: 'Custom',
    description: 'Manual crop setup',
    daysToHarvest: 30,
    ph: SensorRange(5.5, 7.5),
    tds: SensorRange(200, 2000),
    temperature: SensorRange(18, 30),
    humidity: SensorRange(50, 90),
  );

  static const presets = [
    custom,
    PlantPreset(
      key: 'lettuce',
      label: 'Lettuce',
      description: 'Leafy greens, mild nutrient strength',
      daysToHarvest: 35,
      ph: SensorRange(5.8, 6.5),
      tds: SensorRange(560, 840),
      temperature: SensorRange(18, 24),
      humidity: SensorRange(50, 70),
    ),
    PlantPreset(
      key: 'basil',
      label: 'Basil',
      description: 'Herbs, warm and steady growth',
      daysToHarvest: 45,
      ph: SensorRange(5.5, 6.5),
      tds: SensorRange(700, 1120),
      temperature: SensorRange(20, 28),
      humidity: SensorRange(50, 75),
    ),
    PlantPreset(
      key: 'pechay',
      label: 'Pechay',
      description: 'Fast-growing leafy brassica',
      daysToHarvest: 30,
      ph: SensorRange(6.0, 7.0),
      tds: SensorRange(700, 1050),
      temperature: SensorRange(18, 27),
      humidity: SensorRange(55, 80),
    ),
    PlantPreset(
      key: 'tomato',
      label: 'Tomato',
      description: 'Fruiting crop, stronger nutrients',
      daysToHarvest: 75,
      ph: SensorRange(5.8, 6.8),
      tds: SensorRange(1400, 3500),
      temperature: SensorRange(20, 28),
      humidity: SensorRange(55, 75),
    ),
  ];

  static PlantPreset byKey(String? key) =>
      presets.firstWhere((preset) => preset.key == key, orElse: () => custom);
}
