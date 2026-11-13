import 'dart:async';

import 'package:fl_clash/common/cache.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';

const _maxCachedIconBytes = 16 << 20;

// The precache and the widget must resolve equal providers to share one
// ImageCache entry; 192 physical pixels cover a 48 dp icon box at 4x.
const _iconDecodeExtent = 192;

ImageProvider _iconImage(Uint8List bytes) {
  return ResizeImage(
    MemoryImage(bytes),
    width: _iconDecodeExtent,
    height: _iconDecodeExtent,
    policy: ResizeImagePolicy.fit,
  );
}

class _IconBytesCache {
  _IconBytesCache(this.maxBytes);

  final int maxBytes;
  final _entries = <String, Uint8List?>{};
  var _bytes = 0;

  bool contains(String key) => _entries.containsKey(key);

  Uint8List? operator [](String key) {
    if (!_entries.containsKey(key)) {
      return null;
    }
    return _entries[key] = _entries.remove(key);
  }

  void operator []=(String key, Uint8List? value) {
    remove(key);
    final size = value?.lengthInBytes ?? 0;
    if (size > maxBytes) {
      return;
    }
    _entries[key] = value;
    _bytes += size;
    while (_bytes > maxBytes) {
      remove(_entries.keys.first);
    }
  }

  void remove(String key) {
    _bytes -= _entries.remove(key)?.lengthInBytes ?? 0;
  }

  Iterable<String> get keys => _entries.keys;

  void clear() {
    _entries.clear();
    _bytes = 0;
  }
}

final _decodedIcons = _IconBytesCache(_maxCachedIconBytes);
final _remoteIcons = _IconBytesCache(_maxCachedIconBytes);

Uint8List? _decodeIcon(String src) {
  if (!src.contains('base64,')) {
    return null;
  }
  if (_decodedIcons.contains(src)) {
    return _decodedIcons[src];
  }
  return _decodedIcons[src] = src.getBase64;
}

class CommonTargetIcon extends StatelessWidget {
  final String src;

  /// Shown while [src] is empty, loading or unreadable.
  final Widget? fallback;

  const CommonTargetIcon({super.key, required this.src, this.fallback});

  Widget _defaultIcon() {
    return fallback ?? const _ImagePlaceholder();
  }

  Widget _buildIcon() {
    if (src.isEmpty) {
      return _defaultIcon();
    }

    final base64 = _decodeIcon(src);
    if (base64 != null) {
      return _BytesImage(
        bytes: base64,
        isSvg: src.isSvg,
        fallback: _defaultIcon(),
        loadingWidget: fallback,
      );
    }

    return ImageCacheWidget(
      src: src,
      defaultWidget: _defaultIcon(),
      loadingWidget: fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildIcon();
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final size = IconTheme.of(context).size ?? 24;
    final colorScheme = context.colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: GlyphIcon(
          AppGlyphs.photos,
          size: size * 0.7,
          color: Color.alphaBlend(
            colorScheme.onSurfaceVariant.opacity50,
            colorScheme.surface,
          ),
        ),
      ),
    );
  }
}

/// Stands for a proxy group without an icon: the first letter or digit of
/// its name, past any leading emoji the name already shows.
class GroupMonogram extends StatelessWidget {
  final String name;

  const GroupMonogram(this.name, {super.key});

  static final _letter = RegExp(r'[\p{L}\p{N}]', unicode: true);

  String get _mark {
    final letter = _letter.firstMatch(name)?.group(0);
    if (letter != null) {
      return letter.toUpperCase();
    }
    return name.characters.firstOrNull ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = iconTheme.size ?? 24;
    final mark = _mark;
    if (mark.isEmpty) {
      return const _ImagePlaceholder();
    }
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: EmojiText(
          mark,
          maxLines: 1,
          style: AppTextStyle.custom(
            context,
            size: size * 0.62,
            leading: size * 0.62,
            weight: FontWeight.w600,
          ).copyWith(color: iconTheme.color),
        ),
      ),
    );
  }
}

class _BytesImage extends StatefulWidget {
  const _BytesImage({
    required this.bytes,
    required this.isSvg,
    required this.fallback,
    this.loadingWidget,
    this.onError,
  });

  final Uint8List bytes;
  final bool isSvg;
  final Widget fallback;
  final Widget? loadingWidget;
  final VoidCallback? onError;

  @override
  State<_BytesImage> createState() => _BytesImageState();
}

class _BytesImageState extends State<_BytesImage> {
  bool _hasRasterFrame = false;

  @override
  void didUpdateWidget(covariant _BytesImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSvg != widget.isSvg) _hasRasterFrame = false;
  }

  Widget _buildFallback() {
    widget.onError?.call();
    return widget.fallback;
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.loadingWidget;
    return widget.isSvg
        ? SvgPicture.memory(
            widget.bytes,
            placeholderBuilder: loading == null ? null : (_) => loading,
            errorBuilder: (_, _, _) => _buildFallback(),
          )
        : Image(
            image: _iconImage(widget.bytes),
            gaplessPlayback: true,
            frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
              _hasRasterFrame |= wasSynchronouslyLoaded || frame != null;
              return _hasRasterFrame ? child : loading ?? child;
            },
            errorBuilder: (_, _, _) => _buildFallback(),
          );
  }
}

final _defaultCacheManager = CacheManager(
  Config(
    DefaultCacheManager.key,
    fileService: HttpFileService()..concurrentFetches = maxConcurrentIconLoads,
  ),
);

CacheManager? _cacheManagerOverride;
CacheManager get _cacheManager => _cacheManagerOverride ?? _defaultCacheManager;
final _iconCacheRevision = ValueNotifier(0);
final _pendingIconReads = <Future<void>>{};
Future<void>? _refreshingIcons;

@visibleForTesting
set targetIconCacheManager(CacheManager? value) {
  _cacheManagerOverride = value;
}

Future<void> refreshTargetIcons(
  Iterable<String> sources, {
  Future<Iterable<String>> Function()? reloadSources,
}) {
  return _refreshingIcons ??=
      _refreshTargetIcons(sources, reloadSources: reloadSources).whenComplete(
        () {
          _refreshingIcons = null;
          _iconCacheRevision.value++;
        },
      );
}

Future<void> _refreshTargetIcons(
  Iterable<String> sources, {
  Future<Iterable<String>> Function()? reloadSources,
}) async {
  await Future.wait(_pendingIconReads.toList());
  await _cacheManager.emptyCache();
  for (final cache in [_remoteIcons, _decodedIcons]) {
    for (final src in cache.keys.toList()) {
      final bytes = cache[src];
      if (bytes != null && !src.isSvg) {
        await _iconImage(bytes).evict();
      }
    }
    cache.clear();
  }
  svg.cache.clear();
  _iconCacheRevision.value++;
  final urls = {...sources, if (reloadSources != null) ...await reloadSources()}
      .where((src) {
        final uri = Uri.tryParse(src);
        return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      })
      .toList();
  final pool = TaskPool(maxConcurrentIconLoads);
  await Future.wait([
    for (final url in urls)
      pool.run(() async {
        final file = await _cacheManager.downloadFile(
          url,
          force: true,
          authHeaders: const {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        );
        _remoteIcons[url] = await file.file.readAsBytes();
      }),
  ]);
}

Stream<Uint8List> _readCachedIcon(String src) {
  return _cacheManager
      .getFileStreamV2(src)
      .asyncMap((data) => data.file.readAsBytes());
}

var _readRemoteIcon = _readCachedIcon;

@visibleForTesting
set readRemoteIcon(Stream<Uint8List> Function(String src)? value) {
  _readRemoteIcon = value ?? _readCachedIcon;
}

Stream<Uint8List> _loadRemoteIcon(String src) async* {
  final refresh = _refreshingIcons;
  if (refresh != null) {
    await refresh;
  }
  final done = Completer<void>();
  _pendingIconReads.add(done.future);
  final controller = StreamController<Uint8List>();
  // Let an in-flight download finish even if its widget leaves the page,
  // so a cache reset cannot race an older download writing the file back.
  try {
    _readRemoteIcon(src).listen(
      (bytes) {
        final current = _remoteIcons[src];
        controller.add(
          _remoteIcons[src] = current != null && listEquals(current, bytes)
              ? current
              : bytes,
        );
      },
      onError: controller.addError,
      onDone: () {
        _pendingIconReads.remove(done.future);
        done.complete();
        unawaited(controller.close());
      },
    );
  } catch (error, stack) {
    _pendingIconReads.remove(done.future);
    done.complete();
    controller.addError(error, stack);
    unawaited(controller.close());
  }
  yield* controller.stream;
}

Future<void> _decodeAhead(Uint8List bytes) {
  final completer = Completer<void>();
  final stream = _iconImage(bytes).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  void finish() {
    stream.removeListener(listener);
    completer.complete();
  }

  listener = ImageStreamListener(
    (_, _) => finish(),
    onError: (_, _) => finish(),
  );
  stream.addListener(listener);
  return completer.future;
}

Future<void> precacheTargetIcons(Iterable<String> srcs) async {
  final pending = srcs
      .toSet()
      .where(
        (src) =>
            src.isNotEmpty &&
            !src.contains('base64,') &&
            !_remoteIcons.contains(src),
      )
      .map((src) async {
        try {
          await for (final bytes in _loadRemoteIcon(src)) {
            if (!src.isSvg) {
              await _decodeAhead(bytes);
            }
          }
        } catch (error) {
          commonPrint.log('Failed to precache icon $src: $error');
        }
      });
  await Future.wait(pending);
}

class ImageCacheWidget extends StatefulWidget {
  final String src;
  final Widget defaultWidget;
  final Widget? loadingWidget;

  const ImageCacheWidget({
    super.key,
    required this.src,
    required this.defaultWidget,
    this.loadingWidget,
  });

  @override
  State<ImageCacheWidget> createState() => _ImageCacheWidgetState();
}

class _ImageCacheWidgetState extends State<ImageCacheWidget> {
  late final ValueNotifier<Uint8List?> _bytesNotifier;
  StreamSubscription? _streamSubscription;
  var _loadEnded = false;

  @override
  void initState() {
    super.initState();
    _bytesNotifier = ValueNotifier(_remoteIcons[widget.src]);
    _iconCacheRevision.addListener(_reloadIcon);
    _getImageFormCache();
  }

  void _reloadIcon() {
    _bytesNotifier.value = _remoteIcons[widget.src];
    setState(() => _loadEnded = false);
    _getImageFormCache();
  }

  @override
  void didUpdateWidget(covariant ImageCacheWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      _bytesNotifier.value = _remoteIcons[widget.src];
      _loadEnded = false;
      _getImageFormCache();
    }
  }

  void _getImageFormCache() {
    final src = widget.src;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    if (src.isEmpty) {
      return;
    }
    _streamSubscription = _loadRemoteIcon(src).listen(
      (bytes) {
        if (mounted) {
          _bytesNotifier.value = bytes;
        }
      },
      onError: (Object error) {
        commonPrint.log('Failed to read icon $src: $error');
      },
      onDone: () {
        if (mounted && _bytesNotifier.value == null) {
          setState(() => _loadEnded = true);
        }
      },
    );
  }

  @override
  void dispose() {
    _iconCacheRevision.removeListener(_reloadIcon);
    _streamSubscription?.cancel();
    _bytesNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: _bytesNotifier,
      builder: (context, bytes, _) {
        if (bytes == null) {
          return _loadEnded || widget.src.isEmpty
              ? widget.defaultWidget
              : widget.loadingWidget ??
                    SizedBox.square(
                      dimension: IconTheme.of(context).size ?? 24,
                    );
        }
        return _BytesImage(
          bytes: bytes,
          isSvg: widget.src.isSvg,
          fallback: widget.defaultWidget,
          loadingWidget: widget.loadingWidget,
          onError: () => _remoteIcons.remove(widget.src),
        );
      },
    );
  }
}

class PackageIcon extends StatefulWidget {
  final String packageName;
  final double size;

  const PackageIcon({super.key, required this.packageName, required this.size});

  @override
  State<PackageIcon> createState() => _PackageIconState();
}

class _PackageIconState extends State<PackageIcon> {
  ImageProvider? _icon;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _showCachedIcon();
    _loadIcon();
  }

  @override
  void didUpdateWidget(covariant PackageIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) {
      _showCachedIcon();
      _loadIcon();
    }
  }

  void _showCachedIcon() {
    _generation++;
    _icon = app?.getCachedPackageIcon(widget.packageName);
  }

  void _loadIcon() {
    final generation = _generation;
    app?.getPackageIcon(widget.packageName).then((icon) {
      if (!mounted ||
          generation != _generation ||
          icon == null ||
          icon == _icon) {
        return;
      }
      setState(() {
        _icon = icon;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    if (icon == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    return Image(
      image: icon,
      gaplessPlayback: true,
      width: widget.size,
      height: widget.size,
    );
  }
}
