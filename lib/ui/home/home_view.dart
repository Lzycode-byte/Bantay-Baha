import 'package:bantay_baha/domain/models/station.dart';
import 'package:bantay_baha/ui/home/home_viewmodel.dart';
import 'package:bantay_baha/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<HomeViewModel>(
      builder: (context, model, _) {
        final stations = model.stations;
        final highRisk =
            model.metrics?.highRiskStationsCount ??
            stations
                .where((station) => station.riskLevel.toUpperCase() != 'NORMAL')
                .length;
        final peakLevel = model.metrics?.peakWaterLevel ?? 0.0;

        return Column(
          children: [
            Expanded(
              flex: 5,
              child: RefreshIndicator(
                onRefresh: model.refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 150,
                      titleSpacing: 18,
                      title: Row(
                        children: [
                          Icon(
                            Icons.flood_rounded,
                            color: theme.colorScheme.onSurface,
                          ),

                          const SizedBox(width: 9),
                          Text(
                            'Bantay Baha',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        IconButton(
                          onPressed: model.isLoading ? null : model.refresh,
                          tooltip: 'Refresh data',
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        IconButton(
                          onPressed: () => context.go('/advisories'),
                          tooltip: 'Advisories',
                          icon: const Icon(Icons.newspaper),
                        ),
                        IconButton(
                          onPressed: () => context.go('/map'),
                          tooltip: 'Open station map',
                          icon: const Icon(Icons.map_outlined),
                        ),

                        const SizedBox(width: 6),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: DecoratedBox(
                          decoration: BoxDecoration(color: theme.cardColor),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Flood overview',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    model.flood == null
                                        ? 'Live conditions across monitored stations'
                                        : 'Updated ${_dateLabel(model.flood!.calculatedAt)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (model.isLoading)
                      const SliverToBoxAdapter(
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (model.hasFloodError)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Card(
                            color: AppTheme.danger.withValues(alpha: .08),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.cloud_off_outlined,
                                color: AppTheme.danger,
                              ),
                              title: const Text('Live data unavailable'),
                              subtitle: Text(
                                model.floodError ??
                                    'Check your connection and retry.',
                              ),
                              trailing: IconButton(
                                onPressed: model.refresh,
                                tooltip: 'Try again',
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _OverviewCard(
                                label: 'Stations',
                                value:
                                    '${model.metrics?.totalStations ?? stations.length}',
                                icon: Icons.sensors_rounded,
                                color: AppTheme.brandBlue,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _OverviewCard(
                                label: 'At risk',
                                value: '$highRisk',
                                icon: Icons.warning_amber_rounded,
                                color: highRisk > 0
                                    ? AppTheme.warningAmber
                                    : AppTheme.success,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _OverviewCard(
                                label: 'Peak level',
                                value: '${peakLevel.toStringAsFixed(1)} m',
                                icon: Icons.water_rounded,
                                color: AppTheme.brandBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                        child: Row(
                          children: [
                            Icon(
                              highRisk > 0
                                  ? Icons.visibility_outlined
                                  : Icons.verified_outlined,
                              color: highRisk > 0
                                  ? AppTheme.warningAmber
                                  : AppTheme.success,
                              size: 19,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                highRisk > 0
                                    ? '$highRisk station${highRisk == 1 ? '' : 's'} need attention'
                                    : 'All stations reporting normal conditions',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 54,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Monitoring stations',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${stations.length} active',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: stations.isEmpty
                  ? _StationListEmpty(
                      isLoading: model.isLoading,
                      hasError: model.hasFloodError,
                      onRetry: model.refresh,
                    )
                  : RefreshIndicator(
                      onRefresh: model.refresh,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: stations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) =>
                            _StationCard(station: stations[index]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  return '${local.month}/${local.day} at ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: .ellipsis,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _StationCard extends StatelessWidget {
  const _StationCard({required this.station});
  final Station station;

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(station.riskLevel);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    station.stationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    station.riskLevel,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                _Reading(
                  label: 'Water level',
                  value: '${station.waterLevel.toStringAsFixed(1)} m',
                ),
                const SizedBox(width: 24),
                _Reading(
                  label: 'Rain · 1h',
                  value: '${station.rain1h.toStringAsFixed(1)} mm',
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.go('/map'),
                  icon: const Icon(Icons.location_on_outlined, size: 17),
                  label: const Text('Map'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _StationListEmpty extends StatelessWidget {
  const _StationListEmpty({
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError ? Icons.cloud_off_outlined : Icons.sensors_off_outlined,
              size: 34,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(hasError ? 'Station data unavailable' : 'No stations to show'),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
