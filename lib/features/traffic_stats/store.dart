import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

TrafficStatsSettings _decodeTrafficStatsSettings(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const TrafficStatsSettings();
  }
  try {
    return TrafficStatsSettings.fromJson(trafficStatsMap(jsonDecode(raw)));
  } catch (_) {
    return const TrafficStatsSettings();
  }
}

class TrafficStatsSettingsStore extends AsyncNotifier<TrafficStatsSettings> {
  Future<void> _pending = Future.value();

  @override
  Future<TrafficStatsSettings> build() async {
    return _decodeTrafficStatsSettings(
      await preferences.getTrafficStatsSettings(),
    );
  }

  Future<void> updateSettings(
    TrafficStatsSettings Function(TrafficStatsSettings current) update,
  ) {
    return _pending = _pending.catchError((Object _) {}).then((_) async {
      final current = state.value ?? await future;
      final next = update(current);
      if (next == current) {
        return;
      }
      state = AsyncData(next);
      await preferences.setTrafficStatsSettings(jsonEncode(next.toJson()));
    });
  }
}

final trafficStatsStoreProvider =
    AsyncNotifierProvider<TrafficStatsSettingsStore, TrafficStatsSettings>(
      TrafficStatsSettingsStore.new,
    );
