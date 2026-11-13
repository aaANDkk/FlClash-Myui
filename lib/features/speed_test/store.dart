import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

SpeedTestData _decode(String raw) {
  try {
    return SpeedTestData.fromJson(speedTestMap(jsonDecode(raw)));
  } catch (_) {
    return const SpeedTestData();
  }
}

class SpeedTestStore extends AsyncNotifier<SpeedTestData> {
  Future<void> _pending = Future.value();

  @override
  Future<SpeedTestData> build() async {
    final raw = await preferences.getSpeedTestData();
    return raw == null
        ? const SpeedTestData()
        : _retained(await compute(_decode, raw));
  }

  SpeedTestData _retained(SpeedTestData data) {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 14))
        .millisecondsSinceEpoch;
    return SpeedTestData(
      settings: data.settings,
      records: List.unmodifiable(data.records.where((r) => r.time >= cutoff)),
    );
  }

  Future<void> _update(SpeedTestData Function(SpeedTestData) update) {
    return _pending = _pending.catchError((Object _) {}).then((_) async {
      final current = state.value ?? await future;
      final kept = _retained(update(current));
      state = AsyncData(kept);
      await preferences.setSpeedTestData(jsonEncode(kept.toJson()));
    });
  }

  Future<void> settings(SpeedTestSettings settings) => _update(
    (data) => SpeedTestData(settings: settings, records: data.records),
  );

  Future<void> add(SpeedTestRecord record) => _update(
    (data) => SpeedTestData(
      settings: data.settings,
      records: [record, ...data.records],
    ),
  );

  Future<void> clear() =>
      _update((data) => SpeedTestData(settings: data.settings));
}

final speedTestStoreProvider =
    AsyncNotifierProvider<SpeedTestStore, SpeedTestData>(SpeedTestStore.new);
