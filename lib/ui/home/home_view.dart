import 'package:bantay_baha/domain/models/station.dart';
import 'package:bantay_baha/ui/home/home_viewmodel.dart';
import 'package:bantay_baha/ui/map/map_route_args.dart';
import 'package:bantay_baha/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

const double _hPad = 20;

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _attentionOnly = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = theme.scaffoldBackgroundColor;

    return Consumer<HomeViewModel>(
      builder: (context, model, _) {
        final stations = model.stations;

        // Most severe first, then alphabetical.
        final sorted = List<Station>.of(stations)
          ..sort((a, b) {
            final byRisk = _riskRank(a.riskLevel)
                .compareTo(_riskRank(b.riskLevel));
            return byRisk != 0
                ? byRisk
                : a.stationName.compareTo(b.stationName);
          });

        final attentionCount = sorted.where((s) => !_isNormal(s)).length;
        final highRisk = model.metrics?.highRiskStationsCount ?? attentionCount;
        final peakLevel = model.metrics?.peakWaterLevel ?? 0.0;
        final totalStations = model.metrics?.totalStations ?? stations.length;

        final showFilter = attentionCount > 0;
        final filterOn = _attentionOnly && showFilter;
        final visible = filterOn
            ? sorted.where((s) => !_isNormal(s)).toList()
            : sorted;

        final hasData = stations.isNotEmpty;
        final statusColor = model.hasFloodError
            ? scheme.onSurfaceVariant
            : (highRisk > 0 ? AppTheme.warningAmber : AppTheme.success);

        final headline = !hasData
            ? 'Flood overview'
            : highRisk > 0
            ? '$highRisk station${highRisk == 1 ? ' needs' : 's need'} attention'
            : 'All stations normal';

        final support = !hasData
            ? 'Live conditions across monitored stations'
            : (highRisk > 0 && attentionCount > 0)
            ? 'Most severe at ${sorted.first.stationName}'
            : highRisk > 0
            ? 'Peak water level is ${peakLevel.toStringAsFixed(1)} m'
            : 'Water levels are normal across the network';

        return RefreshIndicator(
          onRefresh: model.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                centerTitle: false,
                backgroundColor: bg,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                titleSpacing: _hPad,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flood_rounded,
                      size: 22,
                      color: AppTheme.brandBlue,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Bantay Baha',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                    onPressed: () => context.go('/advisories', extra: model),
                    tooltip: 'Advisories',
                    icon: const Icon(Icons.newspaper_outlined),
                  ),
                  IconButton(
                    onPressed: () => context.go(
                      '/map',
                      extra: MapRouteArgs(model: model),
                    ),
                    tooltip: 'Open station map',
                    icon: const Icon(Icons.map_outlined),
                  ),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: model.isLoading
                      ? const LinearProgressIndicator(minHeight: 2)
                      : const SizedBox(height: 2),
                ),
              ),

              if (model.hasFloodError)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(_hPad, 8, _hPad, 0),
                    child: _ErrorBanner(
                      message:
                          model.floodError ??
                          'Check your connection and try again.',
                      onRetry: model.refresh,
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(_hPad, 24, _hPad, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              model.flood == null
                                  ? 'Live monitoring'
                                  : _updatedLabel(model.flood!.calculatedAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        headline,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        support,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPersistentHeader(
                pinned: true,
                delegate: _StatsHeaderDelegate(
                  background: bg,
                  totalStations: totalStations,
                  highRisk: highRisk,
                  peakLevel: peakLevel,
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(_hPad, 24, _hPad, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              'Stations',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${stations.length} monitored',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (showFilter) ...[
                        const SizedBox(height: 12),
                        _FilterBar(
                          attentionOnly: filterOn,
                          onChanged: (v) => setState(() => _attentionOnly = v),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (stations.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _StationListEmpty(
                    isLoading: model.isLoading,
                    hasError: model.hasFloodError,
                    onRetry: model.refresh,
                  ),
                )
              else if (visible.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No stations match this filter')),
                  ),
                )
              else
                SliverSafeArea(
                  top: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(_hPad, 0, _hPad, 24),
                    sliver: SliverList.separated(
                      itemCount: visible.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) => _StationCard(
                        station: visible[index],
                        model: model,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

bool _isNormal(Station s) => s.riskLevel.toUpperCase() == 'NORMAL';

String _updatedLabel(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Updated just now';
  if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
  if (diff.inHours < 24) return 'Updated ${diff.inHours} h ago';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final l = date.toLocal();
  final h = l.hour.toString().padLeft(2, '0');
  final m = l.minute.toString().padLeft(2, '0');
  return 'Updated ${months[l.month - 1]} ${l.day}, $h:$m';
}

String _sentenceCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

Color _riskColor(String level) {
  final risk = level.toUpperCase();
  if (risk.contains('CRITICAL') ||
      risk.contains('ALARM') ||
      risk.contains('SEVERE') ||
      risk.contains('HIGH')) {
    return AppTheme.danger;
  }
  if (risk.contains('WARNING') ||
      risk.contains('ALERT') ||
      risk.contains('WATCH')) {
    return AppTheme.warningAmber;
  }
  if (risk.contains('NORMAL')) return AppTheme.success;
  return AppTheme.brandBlue;
}

int _riskRank(String level) {
  final c = _riskColor(level);
  if (c == AppTheme.danger) return 0;
  if (c == AppTheme.warningAmber) return 1;
  if (c == AppTheme.success) return 3;
  return 2;
}

class _StatsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StatsHeaderDelegate({
    required this.background,
    required this.totalStations,
    required this.highRisk,
    required this.peakLevel,
  });

  final Color background;
  final int totalStations;
  final int highRisk;
  final double peakLevel;

  @override
  double get maxExtent => 84;

  @override
  double get minExtent => 68;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final divider = VerticalDivider(
      width: 1,
      thickness: 1,
      indent: 4,
      endIndent: 4,
      color: scheme.outlineVariant,
    );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          border: Border(
            top: BorderSide(color: scheme.outlineVariant),
            bottom: BorderSide(
              color: overlapsContent
                  ? scheme.outlineVariant
                  : Colors.transparent,
            ),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _Stat(label: 'Stations', value: '$totalStations'),
              ),
              divider,
              Expanded(
                child: _Stat(
                  label: 'At risk',
                  value: '$highRisk',
                  valueColor: highRisk > 0 ? AppTheme.warningAmber : null,
                ),
              ),
              divider,
              Expanded(
                child: _Stat(
                  label: 'Peak level',
                  value: peakLevel.toStringAsFixed(1),
                  unit: 'm',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StatsHeaderDelegate old) =>
      old.background != background ||
      old.totalStations != totalStations ||
      old.highRisk != highRisk ||
      old.peakLevel != peakLevel;
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                children: [
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.attentionOnly, required this.onChanged});

  final bool attentionOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool selected, bool value) => ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onChanged(value),
    );

    return Material(
      type: MaterialType.transparency,
      child: Wrap(
        spacing: 8,
        children: [
          chip('All', !attentionOnly, false),
          chip('Needs attention', attentionOnly, true),
        ],
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({required this.station, required this.model});
  final Station station;
  final HomeViewModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _riskColor(station.riskLevel);

    final base = scheme.surfaceContainerLow;
    final elevated = color == AppTheme.danger || color == AppTheme.warningAmber;
    final fill = elevated
        ? Color.alphaBlend(color.withValues(alpha: .07), base)
        : base;

    return Material(
      color: fill,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => context.go(
          '/map',
          extra: MapRouteArgs(
            model: model,
            selectedStationId: station.stationId,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      station.stationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: _RiskChip(label: station.riskLevel, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _Reading(
                      label: 'Water level',
                      value: station.waterLevel.toStringAsFixed(1),
                      unit: 'm',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Reading(
                      label: 'Rain, last hour',
                      value: station.rain1h.toStringAsFixed(1),
                      unit: 'mm',
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskChip extends StatelessWidget {
  const _RiskChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _sentenceCase(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              text: value,
              children: [
                TextSpan(
                  text: ' $unit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppTheme.danger,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live data unavailable',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
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
    final theme = Theme.of(context);
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
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasError ? 'Station data unavailable' : 'No stations to show',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
