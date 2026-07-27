import 'package:ahs/data/models/sensor_snapshot.dart';

class SensorThresholds {
  static const double tempMin = 18.0;
  static const double tempMax = 30.0;

  static const double humidMin = 50.0;
  static const double humidMax = 90.0;

  static const double phMin = 5.5;
  static const double phMax = 7.5;

  // The current ESP32 firmware sends this as a raw integer.
  static const double tdsMin = 200.0;
  static const double tdsMax = 2000.0;

  // Ultrasonic distance: larger value means water surface is farther away.
  static const double waterLevelCritical = 20.0;

  static bool isTempCritical(double v) => v < tempMin || v > tempMax;
  static bool isHumidCritical(double v) => v < humidMin || v > humidMax;
  static bool isPhCritical(double v) => v < phMin || v > phMax;
  static bool isTdsCritical(double v) => v < tdsMin || v > tdsMax;
  static bool isWaterCritical(double v) => v > waterLevelCritical;

  static bool anyAnomalyIn(SensorSnapshot s) =>
      isTempCritical(s.temperature) ||
      isHumidCritical(s.humidity) ||
      isPhCritical(s.ph) ||
      isTdsCritical(s.tds) ||
      isWaterCritical(s.waterLevel);
}
