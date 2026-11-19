import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'request_retry.dart';

String _name(Object? value) {
  if (value is! String) return '';
  final text = value.trim();
  return text.toLowerCase() == 'n/a' ? '' : text;
}

class IpLocateInfo {
  const IpLocateInfo({
    required this.ip,
    this.company = '',
    this.network = '',
    this.asn = '',
  });

  final String ip;
  final String company;
  final String network;
  final String asn;

  factory IpLocateInfo.fromJson(Map<String, dynamic> json) => IpLocateInfo(
    ip: _name(json['ip']),
    company: _name((json['company'] as Map?)?['name']),
    network: _name((json['asn'] as Map?)?['name']),
    asn: _name((json['asn'] as Map?)?['asn']),
  );

  Map<String, dynamic> toJson() => {
    'ip': ip,
    'company': {'name': company},
    'asn': {'name': network, 'asn': asn},
  };

  bool get isEmpty => company.isEmpty && network.isEmpty && asn.isEmpty;
}

Future<IpLocateInfo> fetchIpLocate(
  Dio dio,
  String ip,
  CancelToken cancel,
) async {
  final response = await dio.get<Map<String, dynamic>>(
    'https://iplocate.io/api/lookup/${Uri.encodeComponent(ip)}',
    cancelToken: cancel,
    options: Options(
      responseType: ResponseType.json,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );
  final info = IpLocateInfo.fromJson(response.data ?? {});
  if (info.ip != ip || info.isEmpty) {
    throw const FormatException('IPLocate returned no matching attribution');
  }
  return info;
}

typedef ReadIpLocate = Future<Map<String, dynamic>?> Function(String ip);
typedef WriteIpLocate =
    Future<void> Function(String ip, Map<String, dynamic> data);

class IpLocateRepository {
  IpLocateRepository({
    required this.read,
    required this.write,
    required this.fetch,
  });

  final ReadIpLocate read;
  final WriteIpLocate write;
  final Future<IpLocateInfo> Function(String ip, CancelToken cancel) fetch;

  Future<IpLocateInfo?> load(String ip, CancelToken cancel) async {
    try {
      final data = await read(ip);
      if (data != null) {
        final info = IpLocateInfo.fromJson(data);
        if (info.ip == ip && !info.isEmpty) return info;
      }
    } catch (_) {
      // Storage availability does not determine network availability.
    }
    try {
      final info = await retryIpRequest(cancel, () async {
        final result = await fetch(ip, cancel);
        if (result.ip != ip || result.isEmpty) {
          throw const FormatException(
            'IPLocate returned no matching attribution',
          );
        }
        return result;
      }, timeout: const Duration(seconds: 15));
      // Return successful data even while Core is still saving it.
      unawaited(
        Future<void>.sync(
          () => write(ip, info.toJson()),
        ).catchError((Object _) {}),
      );
      return info;
    } catch (_) {
      // Preserve a cache miss on failure so the details page can retry it.
      return null;
    }
  }
}

final ipLocateRepositoryProvider = Provider<IpLocateRepository>((ref) {
  return IpLocateRepository(
    read: (ip) =>
        ref.read(coreHandlerProvider).readIpCache(ip, source: 'iplocate'),
    write: (ip, data) => ref
        .read(coreHandlerProvider)
        .writeIpCache(ip, data, source: 'iplocate'),
    fetch: (ip, cancel) => fetchIpLocate(request.dio, ip, cancel),
  );
});

final ipLocateProvider = FutureProvider.autoDispose
    .family<IpLocateInfo?, String>((ref, ip) async {
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      final info = await ref.read(ipLocateRepositoryProvider).load(ip, cancel);
      if (info != null && ref.mounted) {
        final hold = ref.keepAlive();
        final timer = Timer(const Duration(minutes: 30), hold.close);
        ref.onDispose(timer.cancel);
      }
      return info;
    }, retry: (_, _) => null);
