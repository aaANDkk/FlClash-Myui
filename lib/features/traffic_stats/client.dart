import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class TrafficStatsClient {
  Future<void> configure(
    TrafficStatsSettings settings, {
    required String profile,
    required int tzOffset,
    bool? screenOn,
    bool? suspended,
  });

  Future<TrafficStatsResult> getStats({
    required String start,
    required String end,
    int top = 50,
  });

  Future<void> clear();
}

class _CoreTrafficStatsClient implements TrafficStatsClient {
  const _CoreTrafficStatsClient(this.core);

  final CoreHandlerInterface core;

  @override
  Future<void> configure(
    TrafficStatsSettings settings, {
    required String profile,
    required int tzOffset,
    bool? screenOn,
    bool? suspended,
  }) => core.configureTrafficStats(
    settings,
    profile: profile,
    tzOffset: tzOffset,
    screenOn: screenOn,
    suspended: suspended,
  );

  @override
  Future<TrafficStatsResult> getStats({
    required String start,
    required String end,
    int top = 50,
  }) => core.getTrafficStats(start: start, end: end, top: top);

  @override
  Future<void> clear() => core.clearTrafficStats();
}

final trafficStatsClientProvider = Provider.autoDispose<TrafficStatsClient>(
  (ref) => _CoreTrafficStatsClient(ref.watch(coreHandlerProvider)),
);
