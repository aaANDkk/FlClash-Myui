import 'dart:convert';

import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/features/traffic_stats/store.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'queued settings updates preserve latest state and persist cleanly',
    () async {
      await mockPreferences();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = await container.read(trafficStatsStoreProvider.future);
      expect(initial, const TrafficStatsSettings());

      final store = container.read(trafficStatsStoreProvider.notifier);
      await Future.wait([
        store.updateSettings((s) => s.copyWith(enable: true)),
        store.updateSettings((s) => s.copyWith(detail: false)),
        store.updateSettings(
          (s) => s.copyWith(siteIcon: false, retentionDays: 14),
        ),
      ]);

      final savedRaw = await preferences.getTrafficStatsSettings();
      expect(savedRaw, isNotNull);
      final saved = TrafficStatsSettings.fromJson(
        trafficStatsMap(jsonDecode(savedRaw!)),
      );
      expect(saved.enable, isTrue);
      expect(saved.detail, isFalse);
      expect(saved.siteIcon, isFalse);
      expect(saved.retentionDays, 14);

      container.invalidate(trafficStatsStoreProvider);
      final reloaded = await container.read(trafficStatsStoreProvider.future);
      expect(reloaded, saved);
    },
  );

  test('store clamps retention days and tolerates damaged preferences', () async {
    await mockPreferences({
      'traffic_stats_settings': jsonEncode({
        'enable': true,
        'retentionDays': 999,
      }),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final loaded = await container.read(trafficStatsStoreProvider.future);
    expect(loaded.enable, isTrue);
    expect(loaded.retentionDays, 30);

    await mockPreferences({'traffic_stats_settings': '{invalid-json'});
    container.invalidate(trafficStatsStoreProvider);
    final fallback = await container.read(trafficStatsStoreProvider.future);
    expect(fallback, const TrafficStatsSettings());
  });
}
