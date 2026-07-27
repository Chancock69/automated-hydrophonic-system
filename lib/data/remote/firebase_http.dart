import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ahs/data/models/sensor_snapshot.dart';
import 'package:ahs/data/remote/firebase_config.dart';

// ─────────────────────────────────────────────
//  FirebaseHttp
//  Pure REST — no SDK needed.
//  Firebase Realtime DB exposes every node as:
//    GET  https://{project}.firebaseio.com/{path}.json?auth={token}
// ─────────────────────────────────────────────

class FirebaseHttp {
  FirebaseHttp._();
  static final FirebaseHttp instance = FirebaseHttp._();

  // ── build URL ──────────────────────────────
  Uri _url(String path, {Map<String, String> query = const {}}) {
    final params = <String, String>{...query};
    if (FirebaseConfig.hasAuthToken) {
      params['auth'] = FirebaseConfig.authToken;
    }
    final configured = FirebaseConfig.databaseHost.trim();
    final base = configured.startsWith('http')
        ? Uri.parse(configured)
        : Uri.https(configured);
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final fullPath = [
      if (basePath.isNotEmpty) basePath,
      if (cleanPath.isNotEmpty) cleanPath,
    ].join('/');
    final jsonPath = fullPath.isEmpty ? '/.json' : '/$fullPath.json';
    return base.replace(path: jsonPath, queryParameters: params);
  }

  // ── fetch the latest reading for today ─────
  // Firebase path: /{year}/{MM}/{DD}
  // Each key under the day node is "HH:mm"
  Future<SensorSnapshot?> fetchLatest() async {
    final now = DateTime.now();
    return await _fetchLatestForDate(now) ?? await _fetchLatestAvailable();
  }

  Future<SensorSnapshot?> _fetchLatestForDate(DateTime date) async {
    final path = _dayPath(date);
    try {
      final res = await http
          .get(_url(path))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body);
      if (body == null || body is! Map) return null;

      // body is already promoted to Map after the is! guard — no cast needed
      final keys =
          body.keys
              .map((key) => key.toString())
              .where(_isReadingTimeKey)
              .toList()
            ..sort();
      if (keys.isEmpty) return null;

      final latestKey = keys.last;
      final value = body[latestKey];
      if (value is! Map) return null;
      final data = Map<String, dynamic>.from(value);

      final ts = _timestampForKey(date, latestKey);
      return SensorSnapshot.fromJson(data, ts);
    } catch (_) {
      return null;
    }
  }

  Future<SensorSnapshot?> _fetchLatestAvailable() async {
    final years = (await fetchYears()).reversed;
    for (final year in years) {
      final months = (await fetchMonths(year)).reversed;
      for (final month in months) {
        final days = (await fetchDays(year, month)).reversed;
        for (final day in days) {
          final date = DateTime.tryParse('$year-$month-$day');
          if (date == null) continue;
          final snapshot = await _fetchLatestForDate(date);
          if (snapshot != null) return snapshot;
        }
      }
    }
    return null;
  }

  // ── fetch all readings for a specific date ─
  Future<Map<String, SensorSnapshot>> fetchDay(DateTime date) async {
    final path = _dayPath(date);
    try {
      final res = await http
          .get(_url(path))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return {};

      final body = jsonDecode(res.body);
      if (body == null || body is! Map) return {};

      final result = <String, SensorSnapshot>{};
      body.forEach((key, value) {
        try {
          final keyText = key.toString();
          if (!_isReadingTimeKey(keyText) || value is! Map) return;
          final ts = _timestampForKey(date, keyText);
          result[keyText] = SensorSnapshot.fromJson(
            Map<String, dynamic>.from(value),
            ts,
          );
        } catch (_) {}
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  // ── fetch available year keys ───────────────
  // GET /.json?shallow=true  →  top-level keys = years
  Future<List<String>> fetchYears() async {
    try {
      final uri = _url('/', query: {'shallow': 'true'});
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      if (body == null || body is! Map) return [];
      return body.keys.map((key) => key.toString()).toList()..sort();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> fetchMonths(String year) async {
    try {
      final uri = _url('/$year', query: {'shallow': 'true'});
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      if (body == null || body is! Map) return [];
      return body.keys.map((key) => key.toString()).toList()..sort();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> fetchDays(String year, String month) async {
    try {
      final uri = _url('/$year/$month', query: {'shallow': 'true'});
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      if (body == null || body is! Map) return [];
      return body.keys.map((key) => key.toString()).toList()..sort();
    } catch (_) {
      return [];
    }
  }

  // ── helpers ─────────────────────────────────
  Future<List<DateTime>> fetchAvailableDates() async {
    final dates = <DateTime>[];
    final years = await fetchYears();
    for (final year in years) {
      final y = int.tryParse(year);
      if (y == null) continue;

      final months = await fetchMonths(year);
      for (final month in months) {
        final m = int.tryParse(month);
        if (m == null || m < 1 || m > 12) continue;

        final monthKey = m.toString().padLeft(2, '0');
        final days = await fetchDays(year, monthKey);
        for (final day in days) {
          final d = int.tryParse(day);
          if (d == null || d < 1 || d > DateTime(y, m + 1, 0).day) continue;
          dates.add(DateTime(y, m, d));
        }
      }
    }
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  String _dayPath(DateTime d) => '/${d.year}/${_p(d.month)}/${_p(d.day)}';
  String _p(int n) => n.toString().padLeft(2, '0');

  bool _isReadingTimeKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return false;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    return hour != null &&
        minute != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59;
  }

  DateTime _timestampForKey(DateTime date, String key) {
    final tp = key.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(tp[0]),
      int.parse(tp[1]),
    );
  }
}
