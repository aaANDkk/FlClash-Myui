import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final ipRiskProvider = FutureProvider.autoDispose.family<IpRisk, String>((
  ref,
  ip,
) async {
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final result = await fetchIpRisk(request.dio, ip, cancel);
  if (ref.mounted) {
    final hold = ref.keepAlive();
    final timer = Timer(const Duration(minutes: 30), hold.close);
    ref.onDispose(timer.cancel);
  }
  return result;
}, retry: (_, _) => null);
