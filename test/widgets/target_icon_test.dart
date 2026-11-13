import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file/memory.dart';
import 'package:fl_clash/models/models.dart' hide FileInfo;
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';

class _MockIconCache extends Mock implements CacheManager {}

Future<void> _pump(WidgetTester tester, Widget icon) {
  return tester.pumpWidget(
    TestApp(
      child: Center(
        child: IconTheme(data: const IconThemeData(size: 32), child: icon),
      ),
    ),
  );
}

void main() {
  test('refresh removes disk icons and downloads PNG and SVG again, '
      'without restoring unused icons from earlier sessions', () async {
    final manager = _MockIconCache();
    final fs = MemoryFileSystem();
    final file = fs.file('/icon.png')..writeAsBytesSync(_onePixelPng);
    final events = <String>[];
    when(manager.emptyCache).thenAnswer((_) async {
      events.add('clear');
    });
    when(
      () => manager.downloadFile(
        any(),
        force: true,
        authHeaders: any(named: 'authHeaders'),
      ),
    ).thenAnswer((call) async {
      final url = call.positionalArguments.first as String;
      events.add(url);
      return FileInfo(file, FileSource.Online, DateTime.now(), url);
    });
    targetIconCacheManager = manager;
    addTearDown(() => targetIconCacheManager = null);

    await refreshTargetIcons([
      'https://example.com/group.png',
      'https://example.com/group.svg',
      'https://example.com/group.png',
      'data:image/png;base64,embedded',
      'assets/images/icon.png',
      'file:///local/icon.svg',
    ]);

    expect(events.first, 'clear');
    expect(events, isNot(contains('https://example.com/previous-session.svg')));
    expect(events.where((url) => url.endsWith('/group.png')), hasLength(1));
    expect(events, contains('https://example.com/group.svg'));
    expect(events.skip(1).every((url) => url.startsWith('https://')), isTrue);
  });

  test(
    'refresh clears icons before reloading sets and requests fresh images',
    () async {
      final manager = _MockIconCache();
      final events = <String>[];
      final file = MemoryFileSystem().file('/new.png')
        ..writeAsBytesSync(_onePixelPng);
      when(manager.emptyCache).thenAnswer((_) async => events.add('clear'));
      when(
        () => manager.downloadFile(
          any(),
          force: true,
          authHeaders: any(named: 'authHeaders'),
        ),
      ).thenAnswer((call) async {
        expect(call.namedArguments[#authHeaders], {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        });
        final url = call.positionalArguments.first as String;
        events.add(url);
        return FileInfo(file, FileSource.Online, DateTime.now(), url);
      });
      targetIconCacheManager = manager;
      addTearDown(() => targetIconCacheManager = null);
      await refreshTargetIcons(
        const [],
        reloadSources: () async {
          events.add('reload sets');
          return ['https://example.com/latest-cover.png'];
        },
      );
      expect(events, [
        'clear',
        'reload sets',
        'https://example.com/latest-cover.png',
      ]);
    },
  );

  test('IconSet cover getter is accessible statically via IconSetExt', () {
    const iconSet = IconSet(
      id: 1,
      name: 'Test Set',
      url: 'https://example.com/set.json',
      icons: [
        IconSetIcon(name: 'test.png', url: 'https://example.com/test.png'),
      ],
    );
    expect(iconSet.cover, 'https://example.com/test.png');
    final List<IconSet> list = [iconSet];
    final covers = [for (final IconSet set in list) set.cover];
    expect(covers, ['https://example.com/test.png']);
  });

  test('a failed download releases the refresh lock for a retry', () async {
    final manager = _MockIconCache();
    when(manager.emptyCache).thenAnswer((_) async {});
    when(
      () => manager.downloadFile(
        any(),
        force: true,
        authHeaders: any(named: 'authHeaders'),
      ),
    ).thenThrow(StateError('offline'));
    targetIconCacheManager = manager;
    addTearDown(() => targetIconCacheManager = null);

    await expectLater(
      refreshTargetIcons(['https://example.com/offline.svg']),
      throwsStateError,
    );
    await refreshTargetIcons([]);
    verify(manager.emptyCache).called(2);
  });

  testWidgets('a group without an icon shows the first letter of its name, '
      'past a leading emoji', (tester) async {
    for (final (name, mark) in [
      ('🚀 节点选择', '节'),
      ('proxy', 'P'),
      ('♻️ 9 Auto', '9'),
      ('🇭🇰', '🇭🇰'),
    ]) {
      await _pump(
        tester,
        CommonTargetIcon(src: '', fallback: GroupMonogram(name)),
      );

      expect(find.text(mark), findsOne, reason: name);
    }
  });

  testWidgets('a missing image shows a placeholder, as does an empty name', (
    tester,
  ) async {
    await _pump(tester, const CommonTargetIcon(src: ''));

    expect(find.byGlyph(AppGlyphs.photos), findsOne);

    await _pump(tester, const GroupMonogram(''));

    expect(find.byGlyph(AppGlyphs.photos), findsOne);
  });

  testWidgets('the placeholder glyph is opaque, so a grid of icons that '
      'cannot load paints no offscreen layer per tile', (tester) async {
    await _pump(tester, const CommonTargetIcon(src: ''));

    final glyph = tester.widget<GlyphIcon>(find.byGlyph(AppGlyphs.photos));
    expect(glyph.color!.a, 1);
  });

  group('a remote icon', () {
    late List<String> reads;

    setUp(() {
      reads = [];
      readRemoteIcon = (src) {
        reads.add(src);
        return Stream.value(_onePixelPng);
      };
    });

    tearDown(() => readRemoteIcon = null);

    testWidgets('refresh replaces a displayed cached image with new pixels', (
      tester,
    ) async {
      final manager = _MockIconCache();
      final next = (await tester.runAsync(() => _squarePng(2)))!;
      final file = MemoryFileSystem().file('/replacement.png')
        ..writeAsBytesSync(next);
      var refreshed = false;
      readRemoteIcon = (_) => Stream.value(refreshed ? next : _onePixelPng);
      when(manager.emptyCache).thenAnswer((_) async {});
      when(
        () => manager.downloadFile(
          any(),
          force: true,
          authHeaders: any(named: 'authHeaders'),
        ),
      ).thenAnswer((call) async {
        refreshed = true;
        return FileInfo(
          file,
          FileSource.Online,
          DateTime.now(),
          call.positionalArguments.first as String,
        );
      });
      targetIconCacheManager = manager;
      addTearDown(() => targetIconCacheManager = null);
      const src = 'https://example.com/replaced-image.png';
      await _pump(tester, const CommonTargetIcon(src: src));
      await tester.pump();
      await tester.runAsync(
        () => precacheImage(
          tester.widget<Image>(find.byType(Image)).image,
          tester.element(find.byType(Image)),
        ),
      );
      await tester.pump();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image!.width, 1);
      await tester.runAsync(() => refreshTargetIcons([src]));
      await tester.pump();
      await tester.runAsync(
        () => precacheImage(
          tester.widget<Image>(find.byType(Image)).image,
          tester.element(find.byType(Image)),
        ),
      );
      await tester.pump();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image!.width, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a cold group icon stays visible until its first image frame', (
      tester,
    ) async {
      final stream = StreamController<Uint8List>();
      addTearDown(() => unawaited(stream.close()));
      readRemoteIcon = (_) => stream.stream;
      imageCache.clear();
      await _pump(
        tester,
        const SizedBox.square(
          dimension: 32,
          child: CommonTargetIcon(
            src: 'https://example.com/cold-desktop-group.png',
            fallback: GroupMonogram('Proxy'),
          ),
        ),
      );
      expect(find.text('P'), findsOne);
      final size = tester.getSize(find.byType(CommonTargetIcon));
      stream.add(Uint8List.fromList(_onePixelPng));
      await tester.pump();
      final painted =
          find.byType(RawImage).evaluate().isNotEmpty &&
          tester.widget<RawImage>(find.byType(RawImage)).image != null;
      expect(find.text('P'), painted ? findsNothing : findsOne);
      await tester.runAsync(() async {
        await precacheImage(
          tester.widget<Image>(find.byType(Image)).image,
          tester.element(find.byType(Image)),
        );
      });
      await tester.pump();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(find.text('P'), findsNothing);
      expect(tester.getSize(find.byType(CommonTargetIcon)), size);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('refreshing a loaded group keeps its previous image until the '
        'replacement decodes', (tester) async {
      final stream = StreamController<Uint8List>();
      addTearDown(() => unawaited(stream.close()));
      readRemoteIcon = (_) => stream.stream;
      await _pump(
        tester,
        const CommonTargetIcon(
          src: 'https://example.com/refresh-group.png',
          fallback: GroupMonogram('Refresh'),
        ),
      );
      Future<void> finishDecode() async {
        await tester.runAsync(
          () => precacheImage(
            tester.widget<Image>(find.byType(Image)).image,
            tester.element(find.byType(Image)),
          ),
        );
        await tester.pump();
      }

      stream.add(Uint8List.fromList(_onePixelPng));
      await tester.pump();
      await finishDecode();
      expect(find.text('R'), findsNothing);
      final previous = tester.widget<RawImage>(find.byType(RawImage)).image;
      final replacement = (await tester.runAsync(() => _squarePng(2)))!;
      stream.add(replacement);
      await tester.pump();
      await tester.pump();
      expect(find.text('R'), findsNothing);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, previous);
      await finishDecode();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image!.width, 2);
      expect(find.text('R'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a group SVG keeps its fallback through reading and decoding', (
      tester,
    ) async {
      final stream = StreamController<Uint8List>();
      addTearDown(() => unawaited(stream.close()));
      readRemoteIcon = (_) => stream.stream;
      final bytes = Uint8List.fromList(
        utf8.encode(
          '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32">'
          '<rect width="32" height="32" fill="#00aa00"/></svg>',
        ),
      );
      const key = ValueKey('group-svg-paint');
      await _pump(
        tester,
        const SizedBox.square(
          dimension: 32,
          child: RepaintBoundary(
            key: key,
            child: CommonTargetIcon(
              src: 'https://example.com/cold-group.svg',
              fallback: GroupMonogram('SVG'),
            ),
          ),
        ),
      );
      expect(find.text('S'), findsOne);
      stream.add(bytes);
      await tester.pump();
      expect(await _hasPaintedIcon(tester, key), isTrue);
      await tester.runAsync(() async {
        final picture = await vg.loadPicture(SvgBytesLoader(bytes), null);
        picture.picture.dispose();
      });
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsOne);
      expect(find.text('S'), findsNothing);
      expect(await _hasPaintedIcon(tester, key), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a generic image keeps its quiet loading state', (
      tester,
    ) async {
      readRemoteIcon = (_) => const Stream.empty();
      await _pump(
        tester,
        const CommonTargetIcon(src: 'https://example.com/generic-missing.png'),
      );
      expect(find.byGlyph(AppGlyphs.photos), findsNothing);
      await tester.pump();
      expect(find.byGlyph(AppGlyphs.photos), findsOne);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('loads at once on a page that sits still', (tester) async {
      const src = 'https://example.com/still.png';
      await _pump(tester, const CommonTargetIcon(src: src));
      await tester.pump();

      expect(reads, [src]);
      expect(find.byType(Image), findsOne);
    });

    testWidgets('loads while the route bringing it in arrives', (tester) async {
      const src = 'https://example.com/pushed.png';
      await tester.pumpWidget(
        TestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                HostPageRoute<void>(
                  builder: (_) => const Center(
                    child: IconTheme(
                      data: IconThemeData(size: 32),
                      child: CommonTargetIcon(src: src),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(reads, [src]);
      expect(find.byGlyph(AppGlyphs.photos), findsNothing);
      expect(find.byType(Image), findsOne);
      await tester.pumpAndSettle();
    });

    testWidgets('a page pushed again shows a whole set it loaded before '
        'from its first frame', (tester) async {
      readRemoteIcon = (src) {
        reads.add(src);
        return Stream.value(Uint8List.fromList(_onePixelPng));
      };
      final icons = Wrap(
        children: [
          for (var i = 0; i < 340; i++)
            CommonTargetIcon(src: 'https://example.com/set/$i.png'),
        ],
      );
      await _pump(tester, icons);
      await tester.pump();
      await tester.pumpWidget(
        TestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                HostPageRoute<void>(
                  builder: (_) => IconTheme(
                    data: const IconThemeData(size: 32),
                    child: icons,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Image), findsNWidgets(340));
    });

    testWidgets('an oversized icon decodes at icon size, into the one cache '
        'entry its precache filled', (tester) async {
      final png = (await tester.runAsync(() => _squarePng(512)))!;
      readRemoteIcon = (_) => Stream.value(png);
      const src = 'https://example.com/large.png';
      imageCache.clear();
      await tester.runAsync(() => precacheTargetIcons([src]));

      expect(imageCache.currentSize, 1);

      await _pump(tester, const CommonTargetIcon(src: src));
      await tester.pump();

      expect(tester.widget<RawImage>(find.byType(RawImage)).image!.width, 192);
      expect(imageCache.currentSize, 1);
    });

    testWidgets('keeps the group fallback when a load ends without an image', (
      tester,
    ) async {
      readRemoteIcon = (_) => const Stream.empty();
      await _pump(
        tester,
        const CommonTargetIcon(
          src: 'https://example.com/missing.png',
          fallback: GroupMonogram('proxy'),
        ),
      );

      expect(find.text('P'), findsOne);

      await tester.pump();

      expect(find.text('P'), findsOne);
    });
  });
}

Future<bool> _hasPaintedIcon(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      for (var offset = 3; offset < data.lengthInBytes; offset += 4) {
        if (data.getUint8(offset) != 0) return true;
      }
      return false;
    } finally {
      image.dispose();
    }
  }))!;
}

Future<Uint8List> _squarePng(int size) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = const Color(0xFF2196F3),
  );
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
