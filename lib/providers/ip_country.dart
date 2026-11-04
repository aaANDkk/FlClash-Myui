import 'dart:async';

import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/ip_country.g.dart';

@riverpod
Future<String> ipCountry(Ref ref, String ip) async {
  if (!ref.watch(initProvider)) return '';
  final result = await ref.watch(coreHandlerProvider).ipCountry(ip);
  if (ref.mounted) {
    final link = ref.keepAlive();
    final timer = Timer(const Duration(minutes: 30), link.close);
    ref.onDispose(timer.cancel);
  }
  return result;
}
