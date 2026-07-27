import 'package:ahs/data/models/sensor_thresholds.dart';

class MetricStats {
  final double average;
  final double min;
  final double max;
  final double latest;

  const MetricStats({
    required this.average,
    required this.min,
    required this.max,
    required this.latest,
  });

  static MetricStats? fromValues(List<double> values) {
    if (values.isEmpty) return null;
    var min = values.first;
    var max = values.first;
    var sum = 0.0;
    for (final value in values) {
      if (value < min) min = value;
      if (value > max) max = value;
      sum += value;
    }
    return MetricStats(
      average: sum / values.length,
      min: min,
      max: max,
      latest: values.last,
    );
  }
}

class AnalyticsSummary {
  final int totalRecords;
  final int anomalyCount;
  final DateTime? firstTimestamp;
  final DateTime? lastTimestamp;
  final MetricStats? temperature;
  final MetricStats? humidity;
  final MetricStats? ph;
  final MetricStats? tds;
  final MetricStats? waterLevel;

  const AnalyticsSummary({
    required this.totalRecords,
    required this.anomalyCount,
    required this.firstTimestamp,
    required this.lastTimestamp,
    required this.temperature,
    required this.humidity,
    required this.ph,
    required this.tds,
    required this.waterLevel,
  });

  bool get hasData => totalRecords > 0;

  double get anomalyRate =>
      totalRecords == 0 ? 0 : (anomalyCount / totalRecords) * 100;

  factory AnalyticsSummary.fromRows(List<Map<String, dynamic>> rows) {
    final ordered = [...rows]
      ..sort((a, b) {
        final aTs = DateTime.tryParse(a['timestamp']?.toString() ?? '');
        final bTs = DateTime.tryParse(b['timestamp']?.toString() ?? '');
        return (aTs ?? DateTime(0)).compareTo(bTs ?? DateTime(0));
      });

    final temps = <double>[];
    final humids = <double>[];
    final phs = <double>[];
    final tdsValues = <double>[];
    final waterLevels = <double>[];
    var anomalyCount = 0;
    DateTime? first;
    DateTime? last;

    for (final row in ordered) {
      final ts = DateTime.tryParse(row['timestamp']?.toString() ?? '');
      if (ts != null) {
        first ??= ts;
        last = ts;
      }

      final temp = _double(row['temperature']);
      final humid = _double(row['humidity']);
      final ph = _double(row['ph']);
      final tds = _double(row['tds']);
      final water = _double(row['waterLevel']);

      if (temp != null) temps.add(temp);
      if (humid != null) humids.add(humid);
      if (ph != null) phs.add(ph);
      if (tds != null) tdsValues.add(tds);
      if (water != null) waterLevels.add(water);

      final hasAnomaly =
          (temp != null && SensorThresholds.isTempCritical(temp)) ||
          (humid != null && SensorThresholds.isHumidCritical(humid)) ||
          (ph != null && SensorThresholds.isPhCritical(ph)) ||
          (tds != null && SensorThresholds.isTdsCritical(tds)) ||
          (water != null && SensorThresholds.isWaterCritical(water));

      if (hasAnomaly) anomalyCount++;
    }

    return AnalyticsSummary(
      totalRecords: ordered.length,
      anomalyCount: anomalyCount,
      firstTimestamp: first,
      lastTimestamp: last,
      temperature: MetricStats.fromValues(temps),
      humidity: MetricStats.fromValues(humids),
      ph: MetricStats.fromValues(phs),
      tds: MetricStats.fromValues(tdsValues),
      waterLevel: MetricStats.fromValues(waterLevels),
    );
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
