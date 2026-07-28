class SensorSnapshot {
  final double temperature;
  final double humidity;
  final double ph;
  final double tds;
  final double waterLevel;
  final DateTime timestamp;

  const SensorSnapshot({
    required this.temperature,
    required this.humidity,
    required this.ph,
    required this.tds,
    required this.waterLevel,
    required this.timestamp,
  });

  static double _d(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static double normalizePh(double value) {
    if (value <= 14) return value;
    if (value <= 1400) return value / 100;
    return value.clamp(0, 14);
  }

  factory SensorSnapshot.fromJson(Map<String, dynamic> json, DateTime ts) =>
      SensorSnapshot(
        temperature: _d(json['temperature'] ?? json['Temperature']),
        humidity: _d(json['humidity'] ?? json['Humidity']),
        ph: normalizePh(_d(json['PhLevel'] ?? json['ph'] ?? json['pH'])),
        tds: _d(json['TDS'] ?? json['tds']),
        waterLevel: _d(json['water_level'] ?? json['waterLevel']),
        timestamp: ts,
      );

  Map<String, dynamic> toSqlMap({int? plantId, String? plantName}) => {
    'plantId': plantId,
    'plantName': plantName,
    'timestamp': timestamp.toIso8601String(),
    'temperature': temperature,
    'humidity': humidity,
    'ph': ph,
    'tds': tds,
    'waterLevel': waterLevel,
  };
}
