import 'package:bantay_baha/domain/models/advisory.dart';
import 'package:bantay_baha/ui/home/home_viewmodel.dart';
import 'package:bantay_baha/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class AdvisoriesView extends StatefulWidget {
  const AdvisoriesView({super.key});

  @override
  State<AdvisoriesView> createState() => _AdvisoriesViewState();
}

class _AdvisoriesViewState extends State<AdvisoriesView> {
  String _filter = 'All';
  HomeViewModel? _homeViewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final homeViewModel = context.read<HomeViewModel>();
    if (identical(_homeViewModel, homeViewModel)) return;

    _homeViewModel = homeViewModel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_homeViewModel, homeViewModel)) {
        homeViewModel.loadAdvisories();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Consumer<HomeViewModel>(
      builder: (context, model, _) {
        final advisories = model.advisories.where((advisory) {
          return _filter == 'All' ||
              advisory.severity.toLowerCase().contains(_filter.toLowerCase());
        }).toList()..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        final urgentCount = model.advisories.where(_isUrgent).length;

        return RefreshIndicator(
          onRefresh: () => model.loadAdvisories(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                title: const Text('Advisories'),
                leading: IconButton(
                  tooltip: 'Back to overview',
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Refresh advisories',
                    onPressed: model.isLoadingAdvisories
                        ? null
                        : () => model.loadAdvisories(force: true),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
                bottom: model.isLoadingAdvisories
                    ? const PreferredSize(
                        preferredSize: Size.fromHeight(2),
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    : null,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: _AdvisorySummary(
                    total: model.advisories.length,
                    urgent: urgentCount,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Material(
                  type: MaterialType.transparency,
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final filter in const [
                          'All',
                          'High',
                          'Moderate',
                          'Low',
                        ]) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                filter == 'All' ? 'All updates' : filter,
                              ),
                              selected: _filter == filter,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (model.advisoriesError != null && model.advisories.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _AdvisoriesEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: 'Advisories unavailable',
                    message: model.advisoriesError!,
                    action: 'Try again',
                    onAction: () => model.loadAdvisories(force: true),
                  ),
                )
              else if (model.isLoadingAdvisories && model.advisories.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (advisories.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _AdvisoriesEmpty(
                    icon: Icons.campaign_outlined,
                    title: model.advisories.isEmpty
                        ? 'No advisories yet'
                        : 'No matching advisories',
                    message: model.advisories.isEmpty
                        ? 'Flood and road updates will appear here when reported.'
                        : 'Try another severity filter to see more updates.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  sliver: SliverList.separated(
                    itemCount: advisories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _AdvisoryCard(
                      advisory: advisories[index],
                      onTap: () => _showDetails(context, advisories[index]),
                    ),
                  ),
                ),
              if (model.advisoriesError != null && model.advisories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Text(
                      'Showing the latest saved updates. Pull to refresh.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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

bool _isUrgent(Advisory advisory) {
  final severity = advisory.severity.toLowerCase();
  return severity.contains('high') ||
      severity.contains('severe') ||
      severity.contains('critical');
}

Color _severityColor(BuildContext context, String severity) {
  final value = severity.toLowerCase();
  if (value.contains('high') ||
      value.contains('severe') ||
      value.contains('critical')) {
    return AppTheme.danger;
  }
  if (value.contains('moderate') ||
      value.contains('warning') ||
      value.contains('medium')) {
    return AppTheme.warningAmber;
  }
  return AppTheme.success;
}

class _AdvisorySummary extends StatelessWidget {
  const _AdvisorySummary({required this.total, required this.urgent});
  final int total;
  final int urgent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = urgent > 0 ? AppTheme.danger : AppTheme.brandBlue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: .13),
              shape: BoxShape.circle,
            ),
            child: Icon(
              urgent > 0
                  ? Icons.warning_amber_rounded
                  : Icons.campaign_outlined,
              color: tone,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  urgent > 0
                      ? '$urgent urgent update${urgent == 1 ? '' : 's'}'
                      : 'Community updates',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '$total flood and road ${total == 1 ? 'report' : 'reports'}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvisoryCard extends StatelessWidget {
  const _AdvisoryCard({required this.advisory, required this.onTap});
  final Advisory advisory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _severityColor(context, advisory.severity);
    final location = [
      advisory.road,
      advisory.landmark,
      advisory.city,
    ].where((part) => part.trim().isNotEmpty).toSet().join(' · ');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SeverityBadge(label: advisory.severity, color: color),
                  const Spacer(),
                  Text(
                    _timeLabel(advisory.publishedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                advisory.cleanedText,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 14),
              if (location.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.water_drop_outlined, size: 16, color: color),
                  const SizedBox(width: 5),
                  Text(
                    advisory.depthInches > 0
                        ? '${advisory.depthInches} in · ${advisory.depthCategory}'
                        : advisory.depthCategory,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Details',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: scheme.primary,
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

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w800),
    ),
  );
}

class _AdvisoriesEmpty extends StatelessWidget {
  const _AdvisoriesEmpty({
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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
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
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}

Future<void> _showDetails(BuildContext context, Advisory advisory) async {
  final color = _severityColor(context, advisory.severity);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Flood report',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _SeverityBadge(label: advisory.severity, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${advisory.authorName} · ${_timeLabel(advisory.publishedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Text(
              advisory.cleanedText,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            _DetailRow(label: 'Road', value: advisory.road),
            _DetailRow(label: 'Nearby landmark', value: advisory.landmark),
            _DetailRow(label: 'City', value: advisory.city),
            _DetailRow(label: 'Passability', value: advisory.passability),
            _DetailRow(
              label: 'Water depth',
              value:
                  '${advisory.depthCategory}${advisory.depthInches > 0 ? ' · ${advisory.depthInches} in' : ''}',
            ),
            _DetailRow(label: 'Source', value: advisory.source),
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not provided' : value,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

String _timeLabel(DateTime date) {
  final delta = DateTime.now().difference(date);
  if (delta.inMinutes < 1) return 'Just now';
  if (delta.inHours < 1) return '${delta.inMinutes} min ago';
  if (delta.inDays < 1) return '${delta.inHours} hr ago';
  if (delta.inDays < 7) return '${delta.inDays} days ago';
  final local = date.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}
