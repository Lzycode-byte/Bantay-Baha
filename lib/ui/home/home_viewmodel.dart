import 'dart:async';
import 'dart:collection';

import 'package:bantay_baha/domain/models/flood.dart';
import 'package:bantay_baha/domain/models/metrics.dart';
import 'package:bantay_baha/domain/models/station.dart';
import 'package:bantay_baha/domain/repositories/flood_repository.dart';
import 'package:flutter/foundation.dart';

class HomeViewModel extends ChangeNotifier {
  final FloodRepository _floodRepository;

  HomeViewModel({required this._floodRepository});

  Flood? _flood;
  Metrics? _metrics;
  final List<Station> _stations = [];
  late final UnmodifiableListView<Station> _stationsView = UnmodifiableListView(
    _stations,
  );
  Flood? get flood => _flood;
  Metrics? get metrics => _metrics;
  UnmodifiableListView<Station> get stations => _stationsView;

  bool _isLoading = false;
  Timer? _refreshTimer;
  String? _floodError;
  bool get isLoading => _isLoading;
  String? get floodError => _floodError;
  bool get hasFloodError => _floodError != null;

  Future<void> init() async {
    _refreshTimer ??= Timer.periodic(
      const Duration(minutes: 5),
      (_) => refresh(),
    );
    if (_isLoading) return;
    _isLoading = true;

    _floodError = null;

    notifyListeners();

    try {
      await Future.wait([_loadFlood()]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFlood() async {
    try {
      final result = await _floodRepository.getFloodLive();

      if (result == null) {
        throw Exception('Flood data is unavailable.');
      }

      _flood = result;

      _stations
        ..clear()
        ..addAll(result.stations);
      _metrics = result.metrics;

      _floodError = null;
    } catch (error, stackTrace) {
      debugPrint('Flood loading error: $error');
      debugPrintStack(stackTrace: stackTrace);

      _floodError = 'Unable to load flood data.';
    } finally {
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await init();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
