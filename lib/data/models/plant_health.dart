import 'package:ahs/data/models/analytics_summary.dart';
import 'package:ahs/data/models/plant_model.dart';
import 'package:ahs/data/models/plant_preset.dart';
import 'package:ahs/data/models/sensor_snapshot.dart';
import 'package:ahs/data/models/sensor_thresholds.dart';

class PlantHealth {
  final int score;
  final String label;
  final List<String> recommendations;

  const PlantHealth({
    required this.score,
    required this.label,
    required this.recommendations,
  });

  static PlantHealth from({
    required PlantModel plant,
    SensorSnapshot? latest,
    AnalyticsSummary? summary,
    int? aliveCount,
  }) {
    final ranges = SensorThresholds.forPlant(plant);
    var score = 100.0;
    final recommendations = <String>[];

    void check({
      required String name,
      required double? value,
      required SensorRange range,
      required String lowAction,
      required String highAction,
    }) {
      if (value == null) return;
      if (value < range.min) {
        score -= 10;
        recommendations.add(lowAction);
      } else if (value > range.max) {
        score -= 10;
        recommendations.add(highAction);
      }
    }

    check(
      name: 'Temperature',
      value: latest?.temperature ?? summary?.temperature?.latest,
      range: ranges.temperature,
      lowAction: 'Warm the chamber',
      highAction: 'Cool the chamber',
    );
    check(
      name: 'Humidity',
      value: latest?.humidity ?? summary?.humidity?.latest,
      range: ranges.humidity,
      lowAction: 'Increase humidity',
      highAction: 'Improve airflow',
    );
    check(
      name: 'pH',
      value: latest?.ph ?? summary?.ph?.latest,
      range: ranges.ph,
      lowAction: 'Raise pH',
      highAction: 'Check pH',
    );
    check(
      name: 'TDS',
      value: latest?.tds ?? summary?.tds?.latest,
      range: ranges.tds,
      lowAction: 'Add nutrients',
      highAction: 'Dilute nutrients',
    );

    final water = latest?.waterLevel ?? summary?.waterLevel?.latest;
    if (water != null && SensorThresholds.isWaterCritical(water)) {
      score -= 15;
      recommendations.add('Add water');
    }

    if (summary != null && summary.totalRecords > 0) {
      score -= summary.anomalyRate.clamp(0, 35) * 0.55;
    }

    if (aliveCount != null && plant.quantity > 0) {
      final survival = (aliveCount / plant.quantity.clamp(1, 6)) * 100;
      score -= (100 - survival).clamp(0, 60) * 0.35;
    }

    final rounded = score.clamp(0, 100).round();
    final label = rounded >= 85
        ? 'Healthy'
        : rounded >= 65
        ? 'Watch'
        : 'Needs attention';
    if (recommendations.isEmpty) {
      recommendations.add('Keep monitoring');
    }
    return PlantHealth(
      score: rounded,
      label: label,
      recommendations: recommendations.take(4).toList(),
    );
  }
}
