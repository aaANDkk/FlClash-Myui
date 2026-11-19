import 'dart:async';

import 'package:dio/dio.dart';

const _maxAttempts = 3;

Future<T> retryIpRequest<T>(
  CancelToken cancel,
  Future<T> Function() request, {
  required Duration timeout,
}) => _attemptIpRequest(cancel, request).timeout(
  timeout,
  onTimeout: () {
    final error = TimeoutException('IP lookup deadline exceeded', timeout);
    cancel.cancel(error);
    throw error;
  },
);

Future<T> _attemptIpRequest<T>(
  CancelToken cancel,
  Future<T> Function() request,
) async {
  for (var attempt = 1; ; attempt++) {
    if (cancel.isCancelled) throw cancel.cancelError!;
    try {
      final result = await request();
      if (cancel.isCancelled) throw cancel.cancelError!;
      return result;
    } catch (_) {
      if (cancel.isCancelled || attempt == _maxAttempts) rethrow;
    }
  }
}
