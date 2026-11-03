import 'dart:async';
import 'dart:math';

import 'package:bantay_baha/domain/models/station.dart';
import 'package:bantay_baha/ui/home/home_viewmodel.dart';
import 'package:bantay_baha/ui/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

class MapHeaderDelegate extends SliverPersistentHeaderDelegate {
  const MapHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(child: SizedBox.expand(child: child));
  }

  @override
  bool shouldRebuild(MapHeaderDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const String _stationSourceId = 'flood-stations-source';
  static const String _pulseLayerId = 'flood-stations-pulse';
  static const String _markerLayerId = 'flood-stations-markers';

  MapLibreMapController? _controller;
  Station? _selectedStation;
  String? _stationSignature;
  bool _styleReady = false;
  bool _layersReady = false;
  bool _annotationSyncPending = false;
  bool _annotationSyncRunning = false;
  bool _hasFramedStations = false;
  bool _pulseUpdatePending = false;
  double _pulseProgress = 0;
  bool _pulseExpanding = true;
  Timer? _pulseTimer;

  void _onStationFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String featureId,
    String layerId,
    Annotation? annotation,
  ) {
    _selectStation(featureId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, model, _) {
        final stations = model.stations;
        _scheduleAnnotationSync(stations);
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Station map'),
              leading: IconButton(
                tooltip: 'Back to overview',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/'),
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh stations',
                  onPressed: model.isLoading ? null : model.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            SliverPersistentHeader(
              delegate: MapHeaderDelegate(
                minHeight: 150,
                maxHeight: MediaQuery.sizeOf(context).height * 0.8,
                child: Stack(
                  children: [
                    MapLibreMap(
                      styleString: MapLibreStyles.openfreemapLiberty,
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(13.7565, 121.0583),
                        zoom: 7.4,
                      ),
                      compassEnabled: true,
                      onMapCreated: (controller) {
                        _controller = controller;
                      },
                      onStyleLoadedCallback: () {
                        _styleReady = true;
                        _initializeStationLayers();
                      },
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      doubleClickZoomEnabled: true,
                      gestureRecognizers:
                          <Factory<OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                            ),
                          },
                    ),
                    if (model.isLoading && stations.isEmpty)
                      const Align(
                        alignment: Alignment.topCenter,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (model.hasFloodError && stations.isEmpty)
                      _MapMessage(
                        icon: Icons.cloud_off_outlined,
                        title: 'Station data unavailable',
                        message:
                            model.floodError ??
                            'Check your connection and retry.',
                        action: 'Try again',
                        onAction: model.refresh,
                      ),
                    if (!model.isLoading &&
                        !model.hasFloodError &&
                        stations.isEmpty)
                      const _MapMessage(
                        icon: Icons.location_off_outlined,
                        title: 'No stations available',
                        message: 'There are no monitoring stations to display right now.',
                      ),
                    if (stations.isNotEmpty)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: _MapLegend(count: stations.length),
                      ),
                    if (_selectedStation case final station?)
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 18,
                        child: _SelectedStationCard(
                          station: station,
                          onClose: () =>
                              setState(() => _selectedStation = null),
                          onDetails: () => _showStationDetails(station),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _selectStation(String stationId) {
    Station? station;
    for (final item in context.read<HomeViewModel>().stations) {
      if (item.stationId == stationId) {
        station = item;
        break;
      }
    }
    final selectedStation = station;
    if (selectedStation == null || !mounted) return;
    setState(() => _selectedStation = selectedStation);
    _showStationDetails(selectedStation);
  }

  void _scheduleAnnotationSync(List<Station> stations) {
    if (_controller == null ||
        !_layersReady ||
        _annotationSyncPending ||
        _annotationSyncRunning) {
      return;
    }
    final signature = stations
        .map(
          (station) =>
              '${station.stationId}:${station.latitude}:${station.longitude}:${station.riskLevel}',
        )
        .join('|');
    if (signature == _stationSignature) return;
    _stationSignature = signature;
    _annotationSyncPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _annotationSyncPending = false;
      if (mounted) _syncStationAnnotations(stations);
    });
  }

  Future<void> _syncStationAnnotations(List<Station> stations) async {
    final controller = _controller;
    if (controller == null || !_layersReady || _annotationSyncRunning) return;
    _annotationSyncRunning = true;
    final validStations = stations.where(_hasValidCoordinates).toList();
    try {
      await controller.setGeoJsonSource(
        _stationSourceId,
        _stationFeatureCollection(validStations),
      );
      if (validStations.isEmpty) {
        _pulseTimer?.cancel();
        _pulseTimer = null;
        return;
      }
      _startPulseAnimation();
      if (!_hasFramedStations) {
        await _frameStations(controller, validStations);
        _hasFramedStations = true;
      }
    } catch (error) {
      debugPrint('Unable to update map station annotations: $error');
    } finally {
      _annotationSyncRunning = false;
      if (mounted) {
        _scheduleAnnotationSync(context.read<HomeViewModel>().stations);
      }
    }
  }

  Future<void> _initializeStationLayers() async {
    final controller = _controller;
    if (controller == null || !_styleReady || _layersReady) return;
    try {
      await controller.addGeoJsonSource(
        _stationSourceId,
        _stationFeatureCollection(
          context
              .read<HomeViewModel>()
              .stations
              .where(_hasValidCoordinates)
              .toList(),
        ),
        promoteId: 'stationId',
      );
      await controller.addCircleLayer(
        _stationSourceId,
        _pulseLayerId,
        const CircleLayerProperties(
          circleRadius: 14,
          circleColor: [Expressions.get, 'markerColor'],
          circleOpacity: .3,
          circleStrokeWidth: 0,
        ),
        enableInteraction: false,
      );
      await controller.addCircleLayer(
        _stationSourceId,
        _markerLayerId,
        const CircleLayerProperties(
          circleRadius: 8,
          circleColor: [Expressions.get, 'markerColor'],
          circleOpacity: 1,
          circleStrokeWidth: 2.5,
          circleStrokeColor: '#FFFFFF',
        ),
      );
      controller.onFeatureTapped.add(_onStationFeatureTapped);
      _layersReady = true;
      if (!mounted) return;
      _scheduleAnnotationSync(context.read<HomeViewModel>().stations);
    } catch (error) {
      debugPrint('Unable to initialize station map layers: $error');
    }
  }

  Map<String, dynamic> _stationFeatureCollection(List<Station> stations) => {
    'type': 'FeatureCollection',
    'features': stations
        .map(
          (station) => {
            'type': 'Feature',
            'id': station.stationId,
            'properties': {
              'stationId': station.stationId,
              'markerColor': _colorHex(_riskColor(station.riskLevel)),
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [station.longitude, station.latitude],
            },
          },
        )
        .toList(),
  };

  void _startPulseAnimation() {
    if (_pulseTimer != null) return;
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
      final controller = _controller;
      if (controller == null || !_layersReady || _pulseUpdatePending) return;
      _pulseUpdatePending = true;
      _pulseProgress += _pulseExpanding ? .08 : -.08;
      if (_pulseProgress >= 1) {
        _pulseProgress = 1;
        _pulseExpanding = false;
      } else if (_pulseProgress <= 0) {
        _pulseProgress = 0;
        _pulseExpanding = true;
      }
      try {
        await controller.setLayerProperties(
          _pulseLayerId,
          CircleLayerProperties(
            circleRadius: 14 + 10 * _pulseProgress,
            circleOpacity: .3 * (1 - _pulseProgress),
          ),
        );
      } catch (error) {
        _pulseTimer?.cancel();
        _pulseTimer = null;
        debugPrint('Unable to animate station marker pulse: $error');
      } finally {
        _pulseUpdatePending = false;
      }
    });
  }

  Future<void> _frameStations(
    MapLibreMapController controller,
    List<Station> stations,
  ) async {
    if (stations.length == 1) {
      final station = stations.single;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(station.latitude, station.longitude),
          10,
        ),
        duration: const Duration(milliseconds: 450),
      );
      return;
    }

    final latitudes = stations.map((station) => station.latitude);
    final longitudes = stations.map((station) => station.longitude);
    final south = latitudes.reduce((a, b) => a < b ? a : b);
    final north = latitudes.reduce((a, b) => a > b ? a : b);
    final west = longitudes.reduce((a, b) => a < b ? a : b);
    final east = longitudes.reduce((a, b) => a > b ? a : b);
    final latPadding = (north - south) * .03 + .001;
    final lngPadding = (east - west) * .03 + .001;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south - latPadding, west - lngPadding),
          northeast: LatLng(north + latPadding, east + lngPadding),
        ),
        left: 36,
        top: 80,
        right: 36,
        bottom: 150,
      ),
      duration: const Duration(milliseconds: 450),
    );
  }

  bool _hasValidCoordinates(Station station) =>
      station.latitude.isFinite &&
      station.longitude.isFinite &&
      station.latitude >= -90 &&
      station.latitude <= 90 &&
      station.longitude >= -180 &&
      station.longitude <= 180;

  String _colorHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _controller?.onFeatureTapped.remove(_onStationFeatureTapped);
    super.dispose();
  }

  Future<void> _showStationDetails(Station station) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Scrollable(
              viewportBuilder: (context, position) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _RiskDot(
                            color: _riskColor(station.riskLevel),
                            size: 12,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              station.stationName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          _RiskChip(level: station.riskLevel),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _MetricRow(
                        label: 'Water level',
                        value: '${station.waterLevel.toStringAsFixed(1)} m',
                      ),
                      _MetricRow(
                        label: 'Water level change · 1h',
                        value:
                            '${station.waterLevelDelta1h.toStringAsFixed(1)} m',
                      ),
                      _MetricRow(
                        label: 'Rainfall · 10 min',
                        value: '${station.rain10m.toStringAsFixed(1)} mm',
                      ),
                      _MetricRow(
                        label: 'Rainfall · 1 hour',
                        value: '${station.rain1h.toStringAsFixed(1)} mm',
                      ),
                      _MetricRow(
                        label: 'Rainfall · 24 hours',
                        value: '${station.rain24h.toStringAsFixed(1)} mm',
                      ),
                      _MetricRow(
                        label: 'Water risk',
                        value: station.waterRiskLevel,
                      ),
                      _MetricRow(
                        label: 'Rain risk',
                        value: station.rainRiskLevel,
                      ),
                      _MetricRow(
                        label: 'Updated',
                        value: _dateLabel(station.lastUpdated),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  return '${local.month}/${local.day}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

Color _riskColor(String level) {
  final risk = level.toUpperCase();
  if (risk.contains('CRITICAL') || risk.contains('ALARM')) {
    return AppTheme.danger;
  }
  if (risk.contains('WARNING')) return AppTheme.warningAmber;
  if (risk.contains('NORMAL')) return AppTheme.success;
  return AppTheme.brandBlue;
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Material(
    elevation: 2,
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _RiskDot(color: AppTheme.brandBlue, size: 9),
          const SizedBox(width: 8),
          Text(
            '$count monitoring stations',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    ),
  );
}

class _SelectedStationCard extends StatelessWidget {
  const _SelectedStationCard({
    required this.station,
    required this.onClose,
    required this.onDetails,
  });
  final Station station;
  final VoidCallback onClose;
  final VoidCallback onDetails;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RiskDot(color: _riskColor(station.riskLevel), size: 10),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  station.stationName,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _RiskChip(level: station.riskLevel),
              IconButton(
                onPressed: onClose,
                tooltip: 'Close station preview',
                icon: const Icon(Icons.close_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Water  ${station.waterLevel.toStringAsFixed(1)} m',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Text(
                  'Rain  ${station.rain1h.toStringAsFixed(1)} mm/h',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(onPressed: onDetails, child: const Text('Details')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _RiskDot extends StatelessWidget {
  const _RiskDot({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _RiskChip extends StatelessWidget {
  const _RiskChip({required this.level});
  final String level;
  @override
  Widget build(BuildContext context) {
    final color = _riskColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        level,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        // const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      ignoring: action == null,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .93),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 42,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center),
                if (action != null)
                  TextButton(onPressed: onAction, child: Text(action!)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
