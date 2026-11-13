import 'dart:convert';

import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/features/speed_test/store.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/preferences.dart';

SpeedTestRecord _record(String id, [int days = 0]) => SpeedTestRecord(
  time: DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch,
  proxy: 'DIRECT',
  result: SpeedTestState(id: id, phase: SpeedTestPhase.done, download: 20e6),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'queued settings, clear and result writes preserve the latest data',
    () async {
      await mockPreferences();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(speedTestStoreProvider.future);
      final store = container.read(speedTestStoreProvider.notifier);
      await Future.wait([
        store.settings(const SpeedTestSettings(protocol: 'h3', duration: 15)),
        store.add(_record('first')),
        store.clear(),
        store.add(_record('last')),
      ]);
      final saved = SpeedTestData.fromJson(
        speedTestMap(jsonDecode((await preferences.getSpeedTestData())!)),
      );
      expect(saved.settings.protocol, 'h3');
      expect(saved.settings.duration, 15);
      expect(saved.records.map((r) => r.result.id), ['last']);
      container.invalidate(speedTestStoreProvider);
      final loaded = await container.read(speedTestStoreProvider.future);
      expect(loaded.records.single.result.id, 'last');
      expect(loaded.settings.protocol, 'h3');
    },
  );

  test(
    'history retains fourteen days and tolerates damaged preferences',
    () async {
      await mockPreferences({
        'speed_test_data': jsonEncode(
          SpeedTestData(
            records: [_record('recent', 2), _record('expired', 15)],
          ).toJson(),
        ),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        (await container.read(
          speedTestStoreProvider.future,
        )).records.map((r) => r.result.id),
        ['recent'],
      );
      await mockPreferences({'speed_test_data': '{broken'});
      container.invalidate(speedTestStoreProvider);
      expect(
        (await container.read(speedTestStoreProvider.future)).records,
        isEmpty,
      );
    },
  );
}
