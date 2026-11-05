import 'dart:convert';

import 'package:bantay_baha/domain/models/station.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StationReading {
  const StationReading({
    required this.recordedAt,
    required this.waterLevel,
    required this.rain1h,
  });

  final DateTime recordedAt;
  final double waterLevel;
  final double rain1h;

  Map<String, Object> toJson() => {
    'recordedAt': recordedAt.toIso8601String(),
    'waterLevel': waterLevel,
    'rain1h': rain1h,
  };

  factory StationReading.fromJson(Map<String, dynamic> json) => StationReading(
    recordedAt: DateTime.parse(json['recordedAt'] as String),
    waterLevel: (json['waterLevel'] as num).toDouble(),
    rain1h: (json['rain1h'] as num).toDouble(),
  );
}

class StationHistoryService {
  static const _key = 'station_reading_history_v1';
  static const _retention = Duration(hours: 24);
  static const _interval = Duration(minutes: 4);

  Future<Map<String, List<StationReading>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key);
    if (encoded == null) return {};

    try {
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      return decoded.map((stationId, raw) {
        final readings = (raw as List<dynamic>)
            .map((item) => StationReading.fromJson(item as Map<String, dynamic>))
            .toList();
        return MapEntry(stationId, readings);
      });
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Future<Map<String, List<StationReading>>> record(
    List<Station> stations,
    DateTime recordedAt,
  ) async {
    final histories = await load();
    final cutoff = recordedAt.subtract(_retention);
    histories.updateAll((_, readings) {
      readings.removeWhere((reading) => reading.recordedAt.isBefore(cutoff));
      return readings;
    });
    histories.removeWhere((_, readings) => readings.isEmpty);

    for (final station in stations) {
      final readings = histories.putIfAbsent(station.stationId, () => []);
      if (readings.isNotEmpty &&
          recordedAt.difference(readings.last.recordedAt) < _interval) {
        continue;
      }
      readings.add(
        StationReading(
          recordedAt: recordedAt,
          waterLevel: station.waterLevel,
          rain1h: station.rain1h,
        ),
      );
    }

    histories.removeWhere((_, readings) => readings.isEmpty);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(
        histories.map(
          (stationId, readings) => MapEntry(
            stationId,
            readings.map((reading) => reading.toJson()).toList(),
          ),
        ),
      ),
    );
    return histories;
  }
}
