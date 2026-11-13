import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/event.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class SpeedTestClient {
  Stream<SpeedTestState> get updates;
  Future<SpeedTestState> probe(
    SpeedTestSettings settings,
    String proxy,
    String id,
  );
  Future<SpeedTestState> start(
    SpeedTestSettings settings,
    String proxy,
    String id,
  );
  Future<void> cancel(String id);
  Future<List<SpeedTestNode>> servers(String proxy, String search, String id);
}

class _CoreSpeedTestClient with CoreEventListener implements SpeedTestClient {
  _CoreSpeedTestClient(this.core) {
    coreEventManager.addListener(this);
  }
  final CoreHandlerInterface core;
  final _updates = StreamController<SpeedTestState>.broadcast();

  @override
  Stream<SpeedTestState> get updates => _updates.stream;
  @override
  void onSpeedTest(SpeedTestState state) {
    if (!_updates.isClosed) _updates.add(state);
  }

  @override
  Future<SpeedTestState> probe(
    SpeedTestSettings settings,
    String proxy,
    String id,
  ) => core.probeSpeedTest(settings, proxy, id);
  @override
  Future<SpeedTestState> start(
    SpeedTestSettings settings,
    String proxy,
    String id,
  ) => core.startSpeedTest(settings, proxy, id);
  @override
  Future<List<SpeedTestNode>> servers(String proxy, String search, String id) =>
      core.speedTestServers(proxy, search, id);
  @override
  Future<void> cancel(String id) async {
    try {
      await core.cancelSpeedTest(id);
    } catch (error) {
      commonPrint.log('Cancel speed test: $error');
    }
  }

  void dispose() {
    coreEventManager.removeListener(this);
    unawaited(_updates.close());
  }
}

final speedTestClientProvider = Provider.autoDispose<SpeedTestClient>((ref) {
  final client = _CoreSpeedTestClient(ref.watch(coreHandlerProvider));
  ref.onDispose(client.dispose);
  return client;
});
