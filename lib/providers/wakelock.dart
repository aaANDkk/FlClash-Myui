import 'package:fl_clash/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Whether the screen is being kept awake. The state outlives the process so a
/// wakelock the user turned on is restored on the next start.
class WakelockNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> restore() async {
    if (!await preferences.getWakelockEnabled()) {
      return;
    }
    await _apply(true, persist: false);
  }

  Future<void> toggle() async {
    await _apply(!state);
  }

  Future<void> _apply(bool value, {bool persist = true}) async {
    try {
      if (value) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
      state = value;
      if (persist) {
        await preferences.setWakelockEnabled(value);
      }
    } catch (error) {
      commonPrint.log('wakelock toggle error $error');
    }
  }
}

final wakelockProvider = NotifierProvider<WakelockNotifier, bool>(
  WakelockNotifier.new,
);
