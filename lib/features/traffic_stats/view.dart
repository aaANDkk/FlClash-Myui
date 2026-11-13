import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client.dart';
import 'settings.dart';
import 'store.dart';
import 'widgets.dart';

class TrafficStatsView extends ConsumerStatefulWidget {
  const TrafficStatsView({super.key});

  @override
  ConsumerState<TrafficStatsView> createState() => _TrafficStatsViewState();
}

class _TrafficStatsViewState extends ConsumerState<TrafficStatsView>
    with RouteMotionHoldMixin<TrafficStatsView> {
  static const _refreshInterval = Duration(seconds: 30);

  TrafficStatsPeriod _period = TrafficStatsPeriod.day;
  DateTime _anchor = DateTime.now();
  TrafficStatsRankTab _rankTab = TrafficStatsRankTab.domain;
  TrafficStatsResult? _result;
  bool _loading = true;
  bool _refreshing = false;
  Timer? _timer;
  int _requestId = 0;
  int _manualRefreshId = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_refreshInterval, (_) {
      final enabled =
          ref.read(trafficStatsStoreProvider).value?.enable ?? false;
      if (enabled && ref.read(appVisibleProvider)) {
        unawaited(_refresh());
      }
    });
    unawaited(_refresh(initial: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool initial = false, bool manual = false}) async {
    final id = ++_requestId;
    final manualId = manual ? ++_manualRefreshId : 0;
    final startedAt = manual ? DateTime.now() : null;
    if (initial && _result == null && mounted) {
      setState(() => _loading = true);
    }
    if (manual && mounted) {
      setState(() => _refreshing = true);
    }
    try {
      final (start, end) = trafficStatsDateRange(_period, _anchor);
      final result = await ref
          .read(trafficStatsClientProvider)
          .getStats(start: start, end: end);
      if (!mounted || id != _requestId) return;
      updateWhenRouteSettled(() {
        if (!mounted || id != _requestId) return;
        setState(() {
          _result = result;
          _loading = false;
        });
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      updateWhenRouteSettled(() {
        if (!mounted || id != _requestId) return;
        setState(() => _loading = false);
      });
    } finally {
      if (manual) {
        if (startedAt != null && mounted) {
          final elapsed = DateTime.now().difference(startedAt);
          const minSpin = Duration(milliseconds: 350);
          if (elapsed < minSpin) {
            await Future<void>.delayed(minSpin - elapsed);
          }
        }
        if (mounted && manualId == _manualRefreshId) {
          setState(() => _refreshing = false);
        }
      }
    }
  }

  Future<void> _enable() async {
    await ref
        .read(trafficStatsStoreProvider.notifier)
        .updateSettings((s) => s.copyWith(enable: true));
    await _refresh();
  }

  void _changePeriod(TrafficStatsPeriod period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _anchor = DateTime.now();
    });
    unawaited(_refresh());
  }

  void _stepAnchor(int delta) {
    final next = trafficStatsStepAnchor(_period, _anchor, delta);
    setState(() => _anchor = next);
    unawaited(_refresh());
  }

  Future<void> _openSettings() async {
    await showFormSheet<void>(
      context: context,
      props: nestedPagedSheetProps,
      builder: (_) => NestedPagedSheet(
        builder: (_) =>
            TrafficStatsSettingsView(onCleared: () => unawaited(_refresh())),
      ),
    );
    if (mounted) {
      unawaited(_refresh());
    }
  }

  bool _hasAnyData(TrafficStatsResult result) =>
      result.total > 0 ||
      result.series.any((p) => p.total > 0) ||
      result.hosts.isNotEmpty ||
      result.processes.isNotEmpty ||
      result.nodes.isNotEmpty ||
      result.profiles.isNotEmpty ||
      result.rules.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    ref.watch(trafficStatsClientProvider);
    ref.listen(trafficStatsStoreProvider, (prev, next) {
      if (prev?.value != next.value) {
        unawaited(_refresh());
      }
    });

    final l = context.appLocalizations;
    final store = ref.watch(trafficStatsStoreProvider);
    final settings = store.value ?? const TrafficStatsSettings();
    final result = _result ?? const TrafficStatsResult();
    final hasData = _hasAnyData(result);
    final showEmptyDisabled = !settings.enable && !hasData;

    return TrafficStatsScope(
      child: Scaffold(
        title: l.trafficStats,
        groupIconActions: false,
        iconActions: [
          IconButtonData(
            glyph: AppGlyphs.refresh,
            tooltip: l.trafficStatsRefresh,
            isLoading: _refreshing,
            onPressed: _refreshing ? null : () => unawaited(_refresh(manual: true)),
          ),
          IconButtonData(
            glyph: AppGlyphs.sliders,
            tooltip: l.settings,
            onPressed: _openSettings,
          ),
        ],
        body: Builder(
          builder: (context) => NullStatusSwitcher(
            holdsArrival: false,
            isLoading: (_loading && _result == null) || store.isLoading,
            isEmpty: false,
            loadingStatus: const Center(child: ActivityIndicator.page()),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const sidePadding = 16.0;
                const horizontalInsets = EdgeInsets.symmetric(
                  horizontal: sidePadding,
                );
                final isWide = constraints.maxWidth >= 760;
                final verticalPadding = EdgeInsets.only(
                  top: context.contentTopPadding,
                  bottom: 24 + context.bottomInset,
                );

                if (showEmptyDisabled) {
                  return ListView(
                    padding: verticalPadding.add(horizontalInsets),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: TrafficStatsDisabledCard(onEnable: _enable),
                        ),
                      ),
                    ],
                  );
                }

                Widget padded(Widget child) =>
                    Padding(padding: horizontalInsets, child: child);

                return ListView(
                  padding: verticalPadding,
                  children: [
                    padded(
                      TrafficStatsPeriodBar(
                        period: _period,
                        anchor: _anchor,
                        onPeriodChanged: _changePeriod,
                        onStep: _stepAnchor,
                      ),
                    ),
                    if (!settings.enable) ...[
                      const SizedBox(height: 12),
                      padded(TrafficStatsDisabledBanner(onEnable: _enable)),
                    ],
                    const SizedBox(height: 12),
                    if (isWide)
                      padded(
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 238),
                                child: TrafficStatsOverviewCard(result: result),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 238),
                                child: TrafficStatsTrendCard(
                                  points: result.series,
                                  period: _period,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      padded(TrafficStatsOverviewCard(result: result)),
                      const SizedBox(height: 12),
                      padded(
                        TrafficStatsTrendCard(
                          points: result.series,
                          period: _period,
                        ),
                      ),
                    ],
                    if (result.rules.isNotEmpty)
                      TrafficStatsRuleHitsSection(
                        rules: result.rules,
                        totalHits: result.ruleHits,
                        horizontalPadding: sidePadding,
                      ),
                    padded(
                      TrafficStatsRankingSection(
                        result: result,
                        settings: settings,
                        tab: _rankTab,
                        onTabChanged: (tab) => setState(() => _rankTab = tab),
                      ),
                    ),
                    if (result.since.isNotEmpty)
                      padded(ListFooter(text: l.trafficStatsSince(result.since))),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
