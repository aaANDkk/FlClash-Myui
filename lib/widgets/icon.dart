import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_clash/common/cache.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

export 'package:fl_clash/plugins/app_icon.dart'
    show appIconBodies, appIconIdOf, hostAppIconBody;

const _maxCachedIconBytes = 16 << 20;
const _maxConcurrentIconDecodes = 4;

// The decode size is in dp and follows the pixel ratio an image resolves at,
// so the precache resolves at the view's ratio to share the widget's
// ImageCache entry.
const _iconDecodeExtent = 48;

double? _iconDevicePixelRatio() {
  final dispatcher = ui.PlatformDispatcher.instance;
  return dispatcher.implicitView?.devicePixelRatio ??
      dispatcher.views.firstOrNull?.devicePixelRatio;
}

ImageConfiguration _iconImageConfiguration() {
  return ImageConfiguration(devicePixelRatio: _iconDevicePixelRatio());
}

ImageProvider _iconImage(Uint8List bytes) {
  return ResizeImage(
    MemoryImage(bytes),
    width: _iconDecodeExtent,
    height: _iconDecodeExtent,
    policy: ResizeImagePolicy.fit,
    useLogicalSize: true,
  );
}

@immutable
class _SvgRasterKey {
  const _SvgRasterKey(this.bytes, this.maxExtentPx, this.scale);

  final Uint8List bytes;
  final int maxExtentPx;
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is _SvgRasterKey &&
      other.bytes == bytes &&
      other.maxExtentPx == maxExtentPx &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(bytes, maxExtentPx, scale);
}

/// Rasterizes an SVG icon once into Flutter's [ImageCache] so scrolled or
/// newly mounted proxy icons paint synchronously on their first frame and
/// share the same memory-pressure / prewarm lifecycle as raster icons.
class _SvgRasterImageProvider extends ImageProvider<_SvgRasterKey> {
  const _SvgRasterImageProvider(this.bytes);

  final Uint8List bytes;

  @override
  Future<_SvgRasterKey> obtainKey(ImageConfiguration configuration) {
    final scale = configuration.devicePixelRatio ?? 1.0;
    return SynchronousFuture(
      _SvgRasterKey(bytes, (_iconDecodeExtent * scale).ceil(), scale),
    );
  }

  @override
  ImageStreamCompleter loadImage(
    _SvgRasterKey key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      _loadAsync(key),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<_SvgRasterKey>('Image key', key),
      ],
    );
  }

  Future<ImageInfo> _loadAsync(_SvgRasterKey key) async {
    try {
      final pictureInfo = await vg.loadPicture(SvgBytesLoader(key.bytes), null);
      ui.Picture? scaledPicture;
      try {
        final size = pictureInfo.size;
        if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
          throw StateError('Invalid SVG size: $size');
        }
        final scaleFactor = math.min(
          key.maxExtentPx / size.width,
          key.maxExtentPx / size.height,
        );
        final width = math.max(1, (size.width * scaleFactor).round());
        final height = math.max(1, (size.height * scaleFactor).round());
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.scale(scaleFactor);
        canvas.drawPicture(pictureInfo.picture);
        scaledPicture = recorder.endRecording();
        final image = await scaledPicture.toImage(width, height);
        return ImageInfo(image: image, scale: key.scale);
      } finally {
        scaledPicture?.dispose();
        pictureInfo.picture.dispose();
      }
    } catch (_) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _SvgRasterImageProvider && other.bytes == bytes;

  @override
  int get hashCode => bytes.hashCode;
}

ImageProvider _rasterIconImage(Uint8List bytes, {required bool isSvg}) {
  return isSvg ? _SvgRasterImageProvider(bytes) : _iconImage(bytes);
}

class _IconBytesCache {
  _IconBytesCache(this.maxBytes);

  final int maxBytes;
  final _entries = <String, ({Uint8List? bytes, DateTime? validTill})>{};
  var _bytes = 0;

  bool contains(String key) => _entries.containsKey(key);

  Uint8List? operator [](String key) {
    if (!_entries.containsKey(key)) {
      return null;
    }
    final entry = _entries.remove(key)!;
    _entries[key] = entry;
    return entry.bytes;
  }

  Uint8List? freshBytes(String key) {
    final validTill = _entries[key]?.validTill;
    return validTill != null && validTill.isAfter(DateTime.now())
        ? this[key]
        : null;
  }

  void put(String key, Uint8List? bytes, {DateTime? validTill}) {
    remove(key);
    final size = bytes?.lengthInBytes ?? 0;
    if (size > maxBytes) {
      return;
    }
    _entries[key] = (bytes: bytes, validTill: validTill);
    _bytes += size;
    while (_bytes > maxBytes) {
      remove(_entries.keys.first);
    }
  }

  void remove(String key) {
    _bytes -= _entries.remove(key)?.bytes?.lengthInBytes ?? 0;
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
  final bytes = src.getBase64;
  _decodedIcons.put(src, bytes);
  return bytes;
}

class CommonTargetIcon extends StatelessWidget {
  final String src;

  /// Shown while [src] is empty, loading or unreadable.
  final Widget? fallback;

  final bool rasterizeSvg;

  const CommonTargetIcon({
    super.key,
    required this.src,
    this.fallback,
    this.rasterizeSvg = false,
  });

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
        rasterizeSvg: rasterizeSvg,
      );
    }

    return ImageCacheWidget(
      src: src,
      defaultWidget: _defaultIcon(),
      loadingWidget: fallback,
      rasterizeSvg: rasterizeSvg,
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
    this.rasterizeSvg = false,
    this.onError,
  });

  final Uint8List bytes;
  final bool isSvg;
  final Widget fallback;
  final Widget? loadingWidget;
  final bool rasterizeSvg;
  final VoidCallback? onError;

  @override
  State<_BytesImage> createState() => _BytesImageState();
}

class _BytesImageState extends State<_BytesImage> {
  bool _hasRasterFrame = false;

  @override
  void didUpdateWidget(covariant _BytesImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSvg != widget.isSvg ||
        oldWidget.rasterizeSvg != widget.rasterizeSvg) {
      _hasRasterFrame = false;
    }
  }

  Widget _buildFallback() {
    widget.onError?.call();
    return widget.fallback;
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.loadingWidget;
    final size = IconTheme.of(context).size ?? 24;
    if (widget.isSvg && !widget.rasterizeSvg) {
      return SvgPicture.memory(
        widget.bytes,
        width: size,
        height: size,
        fit: BoxFit.scaleDown,
        placeholderBuilder: loading == null ? null : (_) => loading,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }
    return Image(
      image: _rasterIconImage(widget.bytes, isSvg: widget.isSvg),
      width: size,
      height: size,
      fit: BoxFit.scaleDown,
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
    stalePeriod: const Duration(days: 90),
    maxNrOfCacheObjects: 1000,
    fileSystem: IconCacheFileSystem(
      supportPath: () => appPath.homeDirPath,
      temporaryPath: () => appPath.tempPath,
    ),
    fileService: IconFileService()..concurrentFetches = maxConcurrentIconLoads,
  ),
);

CacheManager? _cacheManagerOverride;
CacheManager get _cacheManager => _cacheManagerOverride ?? _defaultCacheManager;
final _iconCacheRevision = ValueNotifier(0);
final _pendingIconReads = <Future<void>>{};
Future<void>? _refreshingIcons;

class _InFlightIconLoad {
  _InFlightIconLoad() : controller = StreamController<Uint8List>.broadcast();

  final StreamController<Uint8List> controller;
  Uint8List? latest;
}

final _inFlightIconLoads = <String, _InFlightIconLoad>{};

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
  final imageConfig = _iconImageConfiguration();
  for (final cache in [_remoteIcons, _decodedIcons]) {
    for (final src in cache.keys.toList()) {
      final bytes = cache[src];
      if (bytes != null) {
        await _rasterIconImage(
          bytes,
          isSvg: src.isSvg,
        ).evict(configuration: imageConfig);
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
        _remoteIcons.put(
          url,
          await file.file.readAsBytes(),
          validTill: file.validTill,
        );
      }),
  ]);
}

typedef _RemoteIconRead = ({Uint8List bytes, DateTime? validTill});

Stream<_RemoteIconRead> _readCachedIcon(String src) {
  return _cacheManager
      .getFileStreamV2(src)
      .asyncMap(
        (data) async =>
            (bytes: await data.file.readAsBytes(), validTill: data.validTill),
      );
}

var _readRemoteIcon = _readCachedIcon;

@visibleForTesting
set readRemoteIcon(Stream<Uint8List> Function(String src)? value) {
  _readRemoteIcon = value == null
      ? _readCachedIcon
      : (src) => value(src).map((bytes) => (bytes: bytes, validTill: null));
}

Stream<Uint8List> _loadRemoteIcon(String src) async* {
  final refresh = _refreshingIcons;
  if (refresh != null) {
    await refresh;
  }
  if (_remoteIcons.freshBytes(src) case final bytes?) {
    yield bytes;
    return;
  }
  final existing = _inFlightIconLoads[src];
  if (existing != null) {
    if (existing.latest case final latest?) {
      yield latest;
    }
    if (!existing.controller.isClosed) {
      yield* existing.controller.stream;
    }
    return;
  }
  final done = Completer<void>();
  _pendingIconReads.add(done.future);
  final load = _InFlightIconLoad();
  _inFlightIconLoads[src] = load;
  // Let an in-flight download finish even if its widget leaves the page,
  // so a cache reset cannot race an older download writing the file back.
  try {
    _readRemoteIcon(src).listen(
      (read) {
        final current = _remoteIcons[src];
        final bytes = current != null && listEquals(current, read.bytes)
            ? current
            : read.bytes;
        _remoteIcons.put(src, bytes, validTill: read.validTill);
        load.latest = bytes;
        load.controller.add(bytes);
      },
      onError: load.controller.addError,
      onDone: () {
        _inFlightIconLoads.remove(src);
        _pendingIconReads.remove(done.future);
        done.complete();
        unawaited(load.controller.close());
      },
    );
  } catch (error, stack) {
    _inFlightIconLoads.remove(src);
    _pendingIconReads.remove(done.future);
    done.complete();
    unawaited(load.controller.close());
    Error.throwWithStackTrace(error, stack);
  }
  if (load.latest case final latest?) {
    yield latest;
  }
  if (!load.controller.isClosed) {
    yield* load.controller.stream;
  }
}

Future<void> _decodeAhead(Uint8List bytes, {required bool isSvg}) {
  final completer = Completer<void>();
  final stream = _rasterIconImage(
    bytes,
    isSvg: isSvg,
  ).resolve(_iconImageConfiguration());
  late final ImageStreamListener listener;
  void finish() {
    if (completer.isCompleted) {
      return;
    }
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
  final unique = <String>{
    for (final src in srcs)
      if (src.isNotEmpty) src,
  };
  if (unique.isEmpty) {
    return;
  }
  final pool = TaskPool(_maxConcurrentIconDecodes);
  await Future.wait([
    for (final src in unique)
      pool.run(() async {
        try {
          if (src.contains('base64,')) {
            final bytes = _decodeIcon(src);
            if (bytes != null) {
              await _decodeAhead(bytes, isSvg: src.isSvg);
            }
            return;
          }
          if (_remoteIcons[src] case final cached?) {
            await _decodeAhead(cached, isSvg: src.isSvg);
            return;
          }
          await for (final bytes in _loadRemoteIcon(src)) {
            await _decodeAhead(bytes, isSvg: src.isSvg);
          }
        } catch (error) {
          commonPrint.log('Failed to precache icon $src: $error');
        }
      }),
  ]);
}

class ImageCacheWidget extends StatefulWidget {
  final String src;
  final Widget defaultWidget;
  final Widget? loadingWidget;
  final bool rasterizeSvg;

  const ImageCacheWidget({
    super.key,
    required this.src,
    required this.defaultWidget,
    this.loadingWidget,
    this.rasterizeSvg = false,
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
          rasterizeSvg: widget.rasterizeSvg,
          onError: () => _remoteIcons.remove(widget.src),
        );
      },
    );
  }
}

class PackageIcon extends ConsumerStatefulWidget {
  final String packageName;
  final double size;

  const PackageIcon({super.key, required this.packageName, required this.size});

  @override
  ConsumerState<PackageIcon> createState() => _PackageIconState();
}

class _PackageIconState extends ConsumerState<PackageIcon>
    with _PackageIconLoader<PackageIcon> {
  @override
  String packageNameOf(PackageIcon widget) => widget.packageName;

  @override
  (ImageProvider?, Future<ImageProvider?>?) lookUp(String packageName) {
    final source = ref.read(packageIconSourceProvider);
    return (
      source?.getCachedPackageIcon(packageName),
      source?.getPackageIcon(packageName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    return packageIconImage(icon, widget.size);
  }
}

/// Shows a package's cached icon at once and the one [lookUp] loads once it
/// lands, unless the widget has moved to another package by then.
mixin _PackageIconLoader<T extends StatefulWidget> on State<T> {
  ImageProvider? icon;
  var _generation = 0;

  String packageNameOf(T widget);

  (ImageProvider?, Future<ImageProvider?>?) lookUp(String packageName);

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (packageNameOf(oldWidget) != packageNameOf(widget)) {
      _resolve();
    }
  }

  void _resolve() {
    final generation = ++_generation;
    final (cached, load) = lookUp(packageNameOf(widget));
    icon = cached;
    load?.then((loaded) {
      if (mounted && generation == _generation) {
        onLoaded(loaded);
      }
    });
  }

  void onLoaded(ImageProvider? loaded) {
    if (loaded != null && loaded != icon) {
      setState(() {
        icon = loaded;
      });
    }
  }
}

Widget packageIconImage(ImageProvider icon, double size) =>
    Image(image: icon, gaplessPlayback: true, width: size, height: size);

/// Shows the icon of [packageName], an id from `appIconIdOf`. Null only where
/// the app is unknown or known to have no icon; else holds the icon room.
class OwnPackageIcon extends ConsumerStatefulWidget {
  final String packageName;
  final double size;
  final Widget Function(BuildContext context, Widget? icon) builder;

  const OwnPackageIcon({
    super.key,
    required this.packageName,
    required this.size,
    required this.builder,
  });

  @override
  ConsumerState<OwnPackageIcon> createState() => _OwnPackageIconState();
}

class _OwnPackageIconState extends ConsumerState<OwnPackageIcon>
    with _PackageIconLoader<OwnPackageIcon> {
  var _holdsRoom = false;

  @override
  String packageNameOf(OwnPackageIcon widget) => widget.packageName;

  @override
  (ImageProvider?, Future<ImageProvider?>?) lookUp(String packageName) {
    final source = packageName.isEmpty
        ? null
        : ref.read(packageIconSourceProvider);
    final cached = source?.getCachedOwnPackageIcon(packageName);
    final load = cached == null ? source?.getOwnPackageIcon(packageName) : null;
    _holdsRoom = load != null;
    return (cached?.icon, load);
  }

  @override
  void onLoaded(ImageProvider? loaded) {
    if (loaded != null) {
      super.onLoaded(loaded);
      return;
    }
    setState(() => _holdsRoom = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final icon = this.icon;
    return widget.builder(
      context,
      icon != null
          ? packageIconImage(icon, size)
          : _holdsRoom
          ? SizedBox.square(dimension: size)
          : null,
    );
  }
}
