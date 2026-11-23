import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'request_retry.dart';
import 'risk_model.dart';
import 'risk_parser.dart';

typedef RiskPayload = ({String ip, List<int> bytes});

IpRisk? _parseRisk(RiskPayload payload) =>
    parseScamalyticsBytes(payload.ip, payload.bytes);

Future<IpRisk> fetchIpRisk(Dio dio, String ip, CancelToken cancelToken) async {
  final response = await dio.get<List<int>>(
    'https://scamalytics.com/ip/${Uri.encodeComponent(ip)}',
    cancelToken: cancelToken,
    options: Options(
      responseType: ResponseType.bytes,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  final result = await compute(_parseRisk, (
    ip: ip,
    bytes: response.data ?? [],
  ));
  if (result == null) {
    throw const FormatException('Scamalytics returned no risk data');
  }
  return result;
}

typedef ReadIpRiskCache = Future<Map<String, dynamic>?> Function(String ip);
typedef WriteIpRiskCache =
    Future<void> Function(String ip, Map<String, dynamic> data);
typedef FetchIpRisk = Future<IpRisk> Function(String ip, CancelToken cancel);

class IpRiskRepository {
  IpRiskRepository({
    required this.read,
    required this.write,
    required this.fetch,
  });

  final ReadIpRiskCache read;
  final WriteIpRiskCache write;
  final FetchIpRisk fetch;
  final _refresh = <String>{};

  void forceNextQuery(String ip) => _refresh.add(ip);

  Future<IpRisk> load(String ip, CancelToken cancel) async {
    if (!_refresh.remove(ip)) {
      try {
        final data = await read(ip);
        if (data != null) {
          final cached = IpRisk.fromJson(data);
          if (cached.ip == ip) return cached;
        }
      } catch (_) {
        // A missing Core or an incompatible cache must not block the query.
      }
    }
    final result = await retryIpRequest(
      cancel,
      () => fetch(ip, cancel),
      timeout: const Duration(seconds: 30),
    );
    // Return successful data even while Core is still saving it.
    unawaited(
      Future<void>.sync(
        () => write(ip, result.toJson()),
      ).catchError((Object _) {}),
    );
    return result;
  }
}

final ipRiskRepositoryProvider = Provider<IpRiskRepository>((ref) {
  return IpRiskRepository(
    read: (ip) => ref.read(coreHandlerProvider).readIpCache(ip),
    write: (ip, data) => ref.read(coreHandlerProvider).writeIpCache(ip, data),
    fetch: (ip, cancel) => fetchIpRisk(request.dio, ip, cancel),
  );
});

void refreshIpRisk(WidgetRef ref, String ip) {
  ref.read(ipRiskRepositoryProvider).forceNextQuery(ip);
  ref.invalidate(ipRiskProvider(ip));
}

final ipRiskProvider = FutureProvider.autoDispose.family<IpRisk, String>((
  ref,
  ip,
) async {
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final result = await ref.read(ipRiskRepositoryProvider).load(ip, cancel);
  if (ref.mounted) {
    final hold = ref.keepAlive();
    final timer = Timer(const Duration(minutes: 30), hold.close);
    ref.onDispose(timer.cancel);
  }
  return result;
}, retry: (_, _) => null);

final proxyExitIpProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  proxyName,
) async {
  final result = await lookupOutboundIp(
    ref.read(coreHandlerProvider),
    proxyName,
  );
  final info = parseOutboundIp(result);
  if (info == null || info.ip.isEmpty) {
    throw const FormatException('Failed to resolve outbound IP');
  }
  return info.ip;
}, retry: (_, _) => null);
