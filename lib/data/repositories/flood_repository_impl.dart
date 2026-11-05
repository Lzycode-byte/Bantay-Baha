import 'dart:convert';
import 'dart:developer';

import 'package:bantay_baha/core/mapper.dart';
import 'package:bantay_baha/data/models/advisories_raw.dart';
import 'package:bantay_baha/data/models/advisory_raw.dart';
import 'package:bantay_baha/data/models/flood_raw.dart';
import 'package:bantay_baha/data/models/telemetry_raw.dart';
import 'package:bantay_baha/data/services/flood_api_service.dart';
import 'package:bantay_baha/domain/models/advisory.dart';
import 'package:bantay_baha/domain/models/flood.dart';
import 'package:bantay_baha/domain/models/telemetry.dart';
import 'package:bantay_baha/domain/repositories/flood_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FloodRepositoryImpl implements FloodRepository {
  static const _floodCacheKey = 'offline_flood_snapshot_v1';
  static const _advisoriesCacheKey = 'offline_advisories_snapshot_v1';

  final FloodApiService _floodApiService;

  bool _isUsingCachedFloodData = false;
  bool _isUsingCachedAdvisories = false;
  DateTime? _floodCacheSavedAt;
  DateTime? _advisoriesCacheSavedAt;

  @override
  bool get isUsingCachedFloodData => _isUsingCachedFloodData;
  @override
  bool get isUsingCachedAdvisories => _isUsingCachedAdvisories;
  @override
  DateTime? get floodCacheSavedAt => _floodCacheSavedAt;
  @override
  DateTime? get advisoriesCacheSavedAt => _advisoriesCacheSavedAt;

  FloodRepositoryImpl(this._floodApiService);

  @override
  Future<Flood?> getFloodLive({Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async {
    _isUsingCachedFloodData = false;
    try {
      final FloodRaw floodRaw = await _floodApiService.fetchFloodLive();
      final Flood flood = floodRaw.toDomain();
      try {
        _floodCacheSavedAt = await _saveSnapshot(
          _floodCacheKey,
          floodRaw.toJson(),
        );
      } catch (error) {
        log('Unable to cache flood snapshot: $error');
      }
      return flood;
    } catch (e) {
      log('$e');
      try {
        final cached = await _readSnapshot(_floodCacheKey);
        if (cached == null) return null;
        final flood = FloodRaw.fromJson(cached.data).toDomain();
        _isUsingCachedFloodData = true;
        _floodCacheSavedAt = cached.savedAt;
        return flood;
      } catch (cacheError) {
        log('Unable to read cached flood snapshot: $cacheError');
        return null;
      }
    }
  }

  @override
  Future<Telemetry?> getTelemetry({Map<String, dynamic>? queryParameters}) async {
    try {
      final TelemetryRaw telemetryRaw = await _floodApiService.fetchTelemetry();
      final Telemetry telemetry = telemetryRaw.toDomain();
      return telemetry;
    } catch (e) {
      log('$e');
      return null;
    }
  }

  @override
  Future<List<Advisory>?> getAdvisories({Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async {
    _isUsingCachedAdvisories = false;
    try {
      final AdvisoriesRaw advisoriesRaw = await _floodApiService
          .fetchAdvisories();
      final List<Advisory>? advisories = advisoriesRaw.advisories
          ?.map((i) => AdvisoryRaw.fromJson(i).toDomain())
          .toList();
      try {
        _advisoriesCacheSavedAt = await _saveSnapshot(
          _advisoriesCacheKey,
          advisoriesRaw.toJson(),
        );
      } catch (error) {
        log('Unable to cache advisories snapshot: $error');
      }
      return advisories;
    } catch (e) {
      log('$e');
      try {
        final cached = await _readSnapshot(_advisoriesCacheKey);
        if (cached == null) return null;
        final raw = AdvisoriesRaw.fromJson(cached.data);
        final advisories = raw.advisories
            ?.map((item) => AdvisoryRaw.fromJson(item).toDomain())
            .toList();
        _isUsingCachedAdvisories = true;
        _advisoriesCacheSavedAt = cached.savedAt;
        return advisories;
      } catch (cacheError) {
        log('Unable to read cached advisories snapshot: $cacheError');
        return null;
      }
    }
  }

  Future<DateTime> _saveSnapshot(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final savedAt = DateTime.now();
    await prefs.setString(
      key,
      jsonEncode({
        'savedAt': savedAt.toIso8601String(),
        'data': data,
      }),
    );
    return savedAt;
  }

  Future<({Map<String, dynamic> data, DateTime? savedAt})?> _readSnapshot(
    String key,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(key);
    if (encoded == null) return null;
    final snapshot = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    final data = Map<String, dynamic>.from(snapshot['data'] as Map);
    return (
      data: data,
      savedAt: DateTime.tryParse(snapshot['savedAt'] as String? ?? ''),
    );
  }
}
