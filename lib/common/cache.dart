import 'dart:async';
import 'dart:io' show FileSystemException;

import 'package:file/file.dart' as file;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' show join;

import 'future.dart';

class IconCacheFileSystem implements FileSystem {
  IconCacheFileSystem({
    required Future<String> Function() supportPath,
    required Future<String> Function() temporaryPath,
  }) : _directory = ResolveOnce(() => _open(supportPath, temporaryPath));

  final ResolveOnce<file.Directory> _directory;

  static Future<file.Directory> _open(
    Future<String> Function() supportPath,
    Future<String> Function() temporaryPath,
  ) async {
    const fs = LocalFileSystem();
    final directory = fs.directory(join(await supportPath(), 'target_icons'));
    if (await directory.exists()) return directory;

    try {
      final legacy = fs.directory(
        join(await temporaryPath(), DefaultCacheManager.key),
      );
      if (await legacy.exists()) {
        await directory.parent.create(recursive: true);
        return await legacy.rename(directory.path);
      }
    } on FileSystemException {
      // The old temporary directory may have been purged during the move.
    }
    return directory.create(recursive: true);
  }

  @override
  Future<file.File> createFile(String name) async {
    final directory = await _directory.value;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.childFile(name);
  }
}

/// Keeps icon responses valid for at least [minCacheDuration] even when a host
/// (such as raw.githubusercontent.com) sends a short `Cache-Control: max-age`.
/// Explicit user refreshes bypass this via `emptyCache()` + `force: true`.
class IconFileService extends FileService {
  IconFileService({
    FileService? inner,
    this.minCacheDuration = const Duration(days: 7),
  }) : _inner = inner ?? HttpFileService();

  final FileService _inner;
  final Duration minCacheDuration;

  @override
  int get concurrentFetches => _inner.concurrentFetches;

  @override
  set concurrentFetches(int value) {
    _inner.concurrentFetches = value;
  }

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _inner.get(url, headers: headers);
    return _MinCacheFileServiceResponse(response, minCacheDuration);
  }
}

class _MinCacheFileServiceResponse implements FileServiceResponse {
  _MinCacheFileServiceResponse(this._inner, this._minCacheDuration);

  final FileServiceResponse _inner;
  final Duration _minCacheDuration;

  @override
  Stream<List<int>> get content => _inner.content;

  @override
  int? get contentLength => _inner.contentLength;

  @override
  int get statusCode => _inner.statusCode;

  @override
  DateTime get validTill {
    final inner = _inner.validTill;
    final floor = DateTime.now().add(_minCacheDuration);
    return inner.isAfter(floor) ? inner : floor;
  }

  @override
  String? get eTag => _inner.eTag;

  @override
  String get fileExtension => _inner.fileExtension;
}

extension CacheManagerExt on CacheManager {
  Stream<FileInfo> getFileStreamV2(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) {
    key ??= url;
    final streamController = StreamController<FileInfo>();
    _pushFileToStream(streamController, url, key, headers);
    return streamController.stream;
  }

  Future<void> _pushFileToStream(
    StreamController<dynamic> streamController,
    String url,
    String? key,
    Map<String, String>? headers,
  ) async {
    key ??= url;
    FileInfo? cacheFile;
    try {
      cacheFile = await getFileFromCache(key);
      if (cacheFile != null) {
        streamController.add(cacheFile);
      }
    } on Object catch (e) {
      cacheLogger.log(
        'CacheManager: Failed to load cached file for $url with error:\n$e',
        CacheManagerLogLevel.debug,
      );
    }
    if (cacheFile == null || cacheFile.validTill.isBefore(DateTime.now())) {
      try {
        final res = (await downloadFile(url, key: key, authHeaders: headers));
        streamController.add(res);
      } on Object catch (e) {
        cacheLogger.log(
          'CacheManager: Failed to download file from $url with error:\n$e',
          CacheManagerLogLevel.debug,
        );
      }
    }
    unawaited(streamController.close());
  }
}
