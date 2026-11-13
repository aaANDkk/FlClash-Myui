import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/speed_test/client.dart';
import 'package:fl_clash/features/speed_test/gauge.dart';
import 'package:fl_clash/features/speed_test/history.dart';
import 'package:fl_clash/features/speed_test/settings.dart';
import 'package:fl_clash/features/speed_test/store.dart';
import 'package:fl_clash/features/speed_test/view.dart';
import 'package:fl_clash/features/speed_test/widgets.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/record.dart';
import 'package:fl_clash/widgets/traffic_chart.dart';
import 'package:fl_clash/ui/ui.dart' as app_ui;
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/test_app.dart';

class _MemoryStore extends SpeedTestStore {
  @override
  Future<SpeedTestData> build() async => const SpeedTestData();
  @override
  Future<void> settings(SpeedTestSettings settings) async {
    state = AsyncData(
      SpeedTestData(
        settings: settings,
        records: state.value?.records ?? const [],
      ),
    );
  }

  @override
  Future<void> add(SpeedTestRecord record) async {
    state = AsyncData(
      SpeedTestData(
        settings: state.value!.settings,
        records: [record, ...state.value!.records],
      ),
    );
  }

  @override
  Future<void> clear() async {
    state = AsyncData(SpeedTestData(settings: state.value!.settings));
  }
}

class _Client implements SpeedTestClient {
  final events = StreamController<SpeedTestState>.broadcast();
  Future<void> dispose() => events.close();
  final cancelled = <String>[];
  final queries = <String>[];
  final probed = <String>[];
  SpeedTestSettings? lastSettings;
  Completer<SpeedTestState>? run;
  String runId = '';
  bool fail = false;
  @override
  Stream<SpeedTestState> get updates => events.stream;
  @override
  Future<SpeedTestState> probe(
    SpeedTestSettings settings,
    String proxy,
    String id,
  ) async {
    probed.add(proxy);
    lastSettings = settings;
    return SpeedTestState(
      id: id,
      server: const SpeedTestServer(
        sponsor: 'Example',
        city: 'Tokyo',
        host: 'speed.example',
      ),
      outbound: SpeedTestOutbound(chains: [proxy.isEmpty ? 'Node A' : proxy]),
    );
  }

  @override
  Future<SpeedTestState> start(
    SpeedTestSettings settings,
    String proxy,
    String id,
  ) async {
    if (fail) throw StateError('Core unavailable');
    runId = id;
    run = Completer();
    return run!.future;
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    if (id == runId && run != null && !run!.isCompleted) {
      run!.complete(SpeedTestState(id: id, error: 'cancelled'));
    }
  }

  @override
  Future<List<SpeedTestNode>> servers(
    String proxy,
    String search,
    String id,
  ) async {
    queries.add(search);
    return const [
      SpeedTestNode(
        host: 'tokyo.example',
        name: 'Tokyo',
        cc: 'JP',
        sponsor: 'Example',
        latency: 12,
      ),
    ];
  }

  void finish() => run!.complete(
    SpeedTestState(
      id: runId,
      phase: SpeedTestPhase.done,
      download: 240e6,
      upload: 80e6,
      latency: 12,
      jitter: 2,
      downloadLatency: 40,
      uploadLatency: 60,
      rpm: 1000,
      bytes: 20000000,
      outbound: const SpeedTestOutbound(chains: ['Node A']),
      server: const SpeedTestServer(sponsor: 'Example', city: 'Tokyo'),
    ),
  );
}

const _preview = ValueKey('speed-preview');
Widget _app(
  _Client client, {
  Locale locale = const Locale('en'),
  bool running = false,
  bool dark = false,
  String nodeName = 'Node A',
  String fontFamily = 'SpeedPreview',
  Widget page = const SpeedTestView(),
}) => RepaintBoundary(
  key: _preview,
  child: TestApp(
    locale: locale,
    theme: app_ui.ThemeData(fontFamily: fontFamily),
    darkTheme: app_ui.ThemeData(
      brightness: Brightness.dark,
      fontFamily: fontFamily,
    ),
    themeMode: dark ? app_ui.ThemeMode.dark : app_ui.ThemeMode.light,
    overrides: [
      speedTestClientProvider.overrideWithValue(client),
      speedTestStoreProvider.overrideWith(_MemoryStore.new),
      moreToolsSelectorStateProvider.overrideWithValue(
        const MoreToolsSelectorState(navigationItems: []),
      ),
      runTimeProvider.overrideWithBuild((_, _) => running ? 1 : null),
      groupsProvider.overrideWithValue([
        Group(
          type: GroupType.Selector,
          name: 'Group',
          now: 'Node B',
          all: [
            const Proxy(name: 'DIRECT', type: 'Direct'),
            Proxy(name: nodeName, type: 'Shadowsocks'),
            const Proxy(name: 'Node B', type: 'Vmess'),
          ],
        ),
      ]),
    ],
    child: page,
  ),
);

void _size(WidgetTester tester, double width, [double height = 1300]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _snapshot(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_preview),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final font = File('.dart_tool/risk-preview-font.ttf');
    if (await font.exists()) {
      await (FontLoader('SpeedPreview')..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          ))
          .load();
    }
  });

  test('model roundtrip and gauge boundaries retain real units', () {
    const settings = SpeedTestSettings(
      duration: 15,
      protocol: 'h3',
      multiThread: false,
      server: SpeedTestNode(host: 'server.example', sponsor: 'Example'),
    );
    final copy = SpeedTestSettings.fromJson(settings.toJson());
    expect(copy.toParams('Node A', 'owned')['provider'], 'speedtest');
    expect(copy.toParams('Node A', 'owned')['streams'], 1);
    expect(copy.server!.host, 'server.example');
    expect(copy.copyWith(automatic: true).server, isNull);
    expect(speedGaugeFraction(0), 0);
    expect(speedGaugeFraction(1e9), 1);
    expect(speedTestValue(2.5e9), '2.50');
    expect(speedTestUnit(2.5e9), 'Gbps');
    expect(SpeedTestState.fromJson({'speed': double.nan}).speed, 0);
  });

  testWidgets(
    'tools keeps one Speedtest entry when other navigation moves away',
    (tester) async {
      _size(tester, 430);
      final client = _Client();
      addTearDown(client.dispose);
      await tester.pumpWidget(_app(client, page: const ToolsView()));
      await tester.pumpAndSettle();
      expect(find.text('Speed Test'), findsOneWidget);
      await tester.tap(find.text('Speed Test'));
      await tester.pumpAndSettle();
      expect(find.byType(SpeedTestView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [360.0, 430.0, 960.0]) {
    testWidgets('Speedtest layout fits $width without other sources', (
      tester,
    ) async {
      _size(tester, width);
      final client = _Client();
      addTearDown(client.dispose);
      await tester.pumpWidget(_app(client, dark: width == 960));
      await tester.pumpAndSettle();
      expect(find.text('Speedtest'), findsOneWidget);
      expect(find.textContaining('Apple'), findsNothing);
      expect(find.textContaining('Cloudflare'), findsNothing);
      expect(find.byType(SpeedTestGauge), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _snapshot(
        tester,
        '.dart_tool/speed-test-layout-${width.toInt()}.png',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('progress uses dashboard waveform and saves completed history', (
    tester,
  ) async {
    _size(tester, 430, 1500);
    final client = _Client();
    addTearDown(client.dispose);
    await tester.pumpWidget(_app(client, locale: const Locale('zh', 'CN')));
    await tester.pumpAndSettle();
    final l = tester.element(find.byType(SpeedTestView)).appLocalizations;
    await tester.tap(find.text(l.speedTestStart));
    await tester.pump();
    client.events.add(
      const SpeedTestState(
        id: 'obsolete-run',
        phase: SpeedTestPhase.download,
        progress: .9,
        speed: 1e9,
      ),
    );
    await tester.pump();
    expect(find.byType(SpeedTestWaveform), findsNothing);
    client.events.add(
      SpeedTestState(
        id: client.runId,
        phase: SpeedTestPhase.download,
        progress: .6,
        speed: 240e6,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SpeedTestWaveform), findsOneWidget);
    expect(find.byType(TrafficBarsChart), findsOneWidget);
    client.events.add(
      SpeedTestState(
        id: client.runId,
        phase: SpeedTestPhase.upload,
        progress: .7,
        speed: 80e6,
      ),
    );
    await tester.pump();
    client.finish();
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpeedTestView)),
    );
    expect(container.read(speedTestStoreProvider).value!.records, hasLength(1));
    expect(find.text(l.speedTestAgain), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _snapshot(tester, '.dart_tool/speed-test-preview.png');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('stop cancels the owned run without recording partial results', (
    tester,
  ) async {
    _size(tester, 430);
    final client = _Client();
    addTearDown(client.dispose);
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Test'));
    await tester.pump();
    final id = client.runId;
    await tester.tap(find.text('Stop Test'));
    await tester.pumpAndSettle();
    expect(client.cancelled, contains(id));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpeedTestView)),
    );
    expect(container.read(speedTestStoreProvider).value!.records, isEmpty);
    expect(find.text('Start Test'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a Core failure releases the start action', (tester) async {
    _size(tester, 430);
    final client = _Client()..fail = true;
    addTearDown(client.dispose);
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Test'));
    await tester.pumpAndSettle();
    expect(find.text('Start Test'), findsOneWidget);
    expect(find.text('Stop Test'), findsNothing);
    final banner = tester
        .widgetList<app_ui.Card>(find.byType(app_ui.Card))
        .where((card) => card.isError);
    expect(banner, hasLength(1));
    final error = tester
        .element(find.byType(SpeedTestView))
        .appLocalizations
        .speedTestErrorUnavailable;
    expect(
      tester.getTopLeft(find.text(error)).dy,
      lessThan(tester.getTopLeft(find.byType(SpeedTestGauge)).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'outbound picker follows rules, direct and nodes without switching a group',
    (tester) async {
      _size(tester, 430);
      final client = _Client();
      addTearDown(client.dispose);
      await tester.pumpWidget(_app(client, running: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Follow Rules'));
      await tester.pumpAndSettle();
      expect(find.text('Direct'), findsWidgets);
      expect(find.text('Node A'), findsWidgets);
      expect(find.text('Node B'), findsOneWidget);
      await tester.tap(find.text('Node A').hitTestable());
      await tester.pumpAndSettle();
      expect(client.probed.last, 'Node A');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpeedTestView)),
      );
      expect(container.read(groupsProvider).single.now, 'Node B');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('server search pushes inside settings at the same sheet height', (
    tester,
  ) async {
    _size(tester, 430);
    final client = _Client();
    addTearDown(client.dispose);
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Speed Test Settings'));
    await tester.pumpAndSettle();
    await _snapshot(tester, '.dart_tool/speed-test-settings.png');
    final size = tester.getSize(find.byType(app_ui.NestedPagedSheet));
    await tester.tap(
      find.descendant(
        of: find.byType(SpeedTestSettingsView),
        matching: find.text('Test Server'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SpeedTestServerPicker), findsOneWidget);
    expect(
      tester.getSize(find.byType(app_ui.NestedPagedSheet)).height,
      closeTo(size.height, 1),
    );
    final page = tester.widget<app_ui.Scaffold>(
      find.descendant(
        of: find.byType(SpeedTestServerPicker),
        matching: find.byType(app_ui.Scaffold),
      ),
    );
    expect(page.searchState, isNotNull);
    page.searchState!.onSearch('Tokyo');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(client.queries.last, 'Tokyo');
    await _snapshot(tester, '.dart_tool/speed-test-servers.png');
    await tester.tap(
      find
          .descendant(
            of: find.byType(SpeedTestServerPicker),
            matching: find.textContaining('Tokyo'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(SpeedTestSettingsView), findsOneWidget);
    final settingsPage = tester.widget<app_ui.Scaffold>(
      find.descendant(
        of: find.byType(SpeedTestSettingsView),
        matching: find.byType(app_ui.Scaffold),
      ),
    );
    settingsPage.confirmationAction!.onPressed!();
    await tester.pumpAndSettle();
    expect(client.lastSettings!.server!.host, 'tokyo.example');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('history opens as a sheet with a native empty state', (
    tester,
  ) async {
    _size(tester, 430);
    final client = _Client();
    addTearDown(client.dispose);
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Test History'));
    await tester.pumpAndSettle();
    expect(find.byType(SpeedTestHistoryView), findsOneWidget);
    expect(find.text('No test history yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('populated Chinese history opens without locale date tables', (
    tester,
  ) async {
    _size(tester, 430, 1800);
    final client = _Client();
    addTearDown(client.dispose);
    final previousLocale = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previousLocale);
    await tester.pumpWidget(_app(client, locale: const Locale('zh', 'CN')));
    await tester.pumpAndSettle();
    final l = tester.element(find.byType(SpeedTestView)).appLocalizations;
    await tester.tap(find.text(l.speedTestStart));
    await tester.pump();
    client.finish();
    await tester.pumpAndSettle();
    Intl.defaultLocale = 'zh_CN';
    await tester.tap(find.byTooltip(l.speedTestHistory));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SpeedTestHistoryView), findsOneWidget);
    await _snapshot(tester, '.dart_tool/speed-test-history-populated.png');
    await tester.tap(find.textContaining('240.0').last);
    await tester.pumpAndSettle();
    expect(find.byType(SpeedTestRecordView), findsOneWidget);
    final summary = find
        .descendant(
          of: find.byType(SpeedTestRecordView),
          matching: find.byType(app_ui.Card),
        )
        .first;
    final details = find.byKey(const ValueKey('speed-record-details'));
    final body = tester.renderObject<RenderBox>(
      find
          .descendant(
            of: find.byType(SpeedTestRecordView),
            matching: find.byType(ListView),
          )
          .first,
    );
    expect(
      body.globalToLocal(tester.getTopLeft(details)).dy -
          body.globalToLocal(tester.getBottomLeft(summary)).dy,
      closeTo(12, .01),
    );
    await _snapshot(tester, '.dart_tool/speed-test-record-details.png');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('long outbound names and live metadata preserve card heights', (
    tester,
  ) async {
    _size(tester, 360, 1700);
    const longName = 'HK-A-02-IEPL [Home] very long node x1.5 2026';
    final client = _Client();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      _app(client, running: true, nodeName: longName, fontFamily: 'Ahem'),
    );
    await tester.pumpAndSettle();
    final view = tester.widget<app_ui.Scaffold>(
      find
          .descendant(
            of: find.byType(SpeedTestView),
            matching: find.byType(app_ui.Scaffold),
          )
          .first,
    );
    expect(view.groupIconActions, isFalse);
    await tester.tap(find.byKey(const ValueKey('speed-test-outbound-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(longName).hitTestable());
    await tester.pumpAndSettle();
    final hero = find
        .ancestor(
          of: find.byType(SpeedTestGauge),
          matching: find.byType(app_ui.Card),
        )
        .first;
    final route = find.byType(SpeedTestConnectionCard);
    final heroHeight = tester.getSize(hero).height;
    final routeHeight = tester.getSize(route).height;
    await tester.tap(find.text('Start Test'));
    await tester.pump();
    for (final phase in [
      SpeedTestPhase.latency,
      SpeedTestPhase.download,
      SpeedTestPhase.upload,
    ]) {
      client.events.add(
        SpeedTestState(
          id: client.runId,
          phase: phase,
          progress: .5,
          speed: 100e6,
          bytes: 20000000,
          fallback: true,
          protocol: 'h1',
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(hero).height, heroHeight);
      expect(tester.getSize(route).height, routeHeight);
      final indicators = find.descendant(
        of: find.byType(SpeedTestStatGrid),
        matching: find.byType(app_ui.ActivityIndicator),
      );
      expect(indicators, findsNWidgets(2));
      final statCards = tester.widgetList<app_ui.Card>(
        find.descendant(
          of: find.byType(SpeedTestStatGrid),
          matching: find.byType(app_ui.Card),
        ),
      );
      for (final card in statCards) {
        expect(card.isSelected, isFalse);
        expect(card.side, BorderSide.none);
        expect(card.selectionTint, isNull);
      }
      expect(tester.takeException(), isNull);
    }
    final protocol = tester.widget<Text>(find.text('HTTP/2 → HTTP/1.1'));
    expect(protocol.maxLines, 2);
    expect(protocol.overflow, isNot(TextOverflow.ellipsis));
    client.finish();
    await tester.pumpAndSettle();
    await _snapshot(tester, '.dart_tool/speed-test-long-node.png');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings persist immediately when the sheet is dismissed', (
    tester,
  ) async {
    _size(tester, 430);
    final client = _Client();
    addTearDown(client.dispose);
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Speed Test Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10s'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20s').last);
    await tester.pumpAndSettle();
    tester.element(find.byType(SpeedTestSettingsView)).safeNestedPop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Speed Test Settings'));
    await tester.pumpAndSettle();
    final saved = tester
        .widget<SpeedTestSettingsView>(find.byType(SpeedTestSettingsView))
        .settings;
    expect(saved.duration, 20);
    expect(saved.protocol, 'h2');
    expect(saved.multiThread, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wide realtime graph uses separate homepage direction charts', (
    tester,
  ) async {
    _size(tester, 900, 650);
    final client = _Client();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      _app(
        client,
        page: app_ui.Scaffold(
          title: 'Realtime',
          body: Center(
            child: SpeedTestWaveform(
              samples: List.generate(
                60,
                (i) => Traffic(down: (i + 1) * 200000, up: (60 - i) * 50000),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final charts = tester
        .widgetList<TrafficBarsChart>(find.byType(TrafficBarsChart))
        .toList();
    expect(charts.map((c) => c.upload), [false, true]);
    final glyphs = tester
        .widgetList<GlyphIcon>(find.byType(GlyphIcon))
        .map((icon) => icon.glyph);
    expect(glyphs, contains(AppGlyphs.arrowDown));
    expect(glyphs, contains(AppGlyphs.arrowUp));
    expect(tester.takeException(), isNull);
    await _snapshot(tester, '.dart_tool/speed-test-wide-waveform.png');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'connection cards separate outbound and server and keep single-line overflow',
    (tester) async {
      _size(tester, 360, 900);
      final client = _Client();
      addTearDown(client.dispose);
      const target =
          'NetNam Corporation · San Jose, California — Speedtest Server';
      await tester.pumpWidget(
        _app(
          client,
          page: const app_ui.Scaffold(
            title: 'Connections',
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SpeedTestConnectionCard(
                  outbound: 'Direct',
                  server: target,
                  selectable: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final value = tester.widget<Text>(find.text(target));
      expect(value.maxLines, 1);
      expect(value.overflow, TextOverflow.ellipsis);
      expect(
        find.descendant(
          of: find.byType(SpeedTestConnectionCard),
          matching: find.byType(app_ui.DecorationListItem),
        ),
        findsNWidgets(2),
      );
      final picker = find.byWidgetPredicate(
        (widget) => widget is GlyphIcon && widget.glyph == Glyphs.picker,
      );
      expect(picker, findsOneWidget);
      expect(tester.takeException(), isNull);
      await _snapshot(tester, '.dart_tool/speed-test-connection-card.png');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('probe marquee paints a single gradient arc', (tester) async {
    _size(tester, 430, 700);
    final client = _Client();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      _app(
        client,
        page: app_ui.Scaffold(
          title: 'Probe',
          body: Builder(
            builder: (context) => Center(
              child: SpeedTestGauge(
                waiting: true,
                color: context.colorScheme.primary,
                otherColor: Color.lerp(
                  context.colorScheme.surface,
                  context.colorScheme.primary,
                  .28,
                )!,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    await _snapshot(tester, '.dart_tool/speed-test-probe-arc.png');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'stat cards keep standard padding, compact single-line height, and native details',
    (tester) async {
      _size(tester, 960, 1400);
      final client = _Client();
      addTearDown(client.dispose);
      await tester.pumpWidget(
        _app(
          client,
          locale: const Locale('zh', 'CN'),
          page: const SpeedTestView(),
        ),
      );
      await tester.pumpAndSettle();
      final l = tester.element(find.byType(SpeedTestView)).appLocalizations;
      await tester.tap(find.text(l.speedTestStart));
      await tester.pump();
      client.finish();
      await tester.pumpAndSettle();

      // Verify VisualDensity.standard preserves symmetrical card padding on desktop.
      final heroCard = find
          .ancestor(
            of: find.byType(SpeedTestGauge),
            matching: find.byType(app_ui.Card),
          )
          .first;
      final heroTitle = find.text('Speedtest');
      expect(
        tester.getTopLeft(heroTitle).dy - tester.getTopLeft(heroCard).dy,
        greaterThanOrEqualTo(20),
      );

      final statCards = find.descendant(
        of: find.byType(SpeedTestStatGrid),
        matching: find.byType(app_ui.Card),
      );
      expect(statCards, findsNWidgets(4));
      final heights = [
        for (var i = 0; i < 4; i++) tester.getSize(statCards.at(i)).height,
      ];
      expect(heights.toSet(), hasLength(1));
      expect(heights.first, lessThan(100));
      expect(
        tester.getTopLeft(find.text(l.delay)).dy -
            tester.getTopLeft(statCards.at(0)).dy,
        closeTo(
          tester.getTopLeft(find.text(l.delay)).dx -
              tester.getTopLeft(statCards.at(0)).dx,
          .01,
        ),
      );
      expect(find.textContaining('↓40 ↑60'), findsOneWidget);

      await tester.tap(find.byTooltip(l.speedTestHistory));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SpeedTestHistoryView),
          matching: find.byType(app_ui.DecorationListItem),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<app_ui.ItemPositionProvider>(
              find
                  .descendant(
                    of: find.byType(SpeedTestHistoryView),
                    matching: find.byType(app_ui.ItemPositionProvider),
                  )
                  .first,
            )
            .position,
        app_ui.ItemPosition.startAndEnd,
      );
      expect(
        find.descendant(
          of: find.byType(SpeedTestHistoryView),
          matching: find.byType(app_ui.DisclosureIndicator),
        ),
        findsNothing,
      );
      await tester.tap(find.textContaining('240.0').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('speed-record-details')),
          matching: find.byType(DetailRow),
        ),
        findsNWidgets(4),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'gauge zeros before probing, restores download progress, and clears needle',
    (tester) async {
      _size(tester, 430, 700);
      final client = _Client();
      addTearDown(client.dispose);
      const done = SpeedTestState(
        phase: SpeedTestPhase.done,
        download: 240e6,
        upload: 60e6,
      );
      Widget buildGauge({required bool waiting}) => _app(
        client,
        page: app_ui.Scaffold(
          title: 'Gauge',
          body: Builder(
            builder: (context) => Center(
              child: SpeedTestGauge(
                state: done,
                waiting: waiting,
                color: context.colorScheme.primary,
                otherColor: Color.lerp(
                  context.colorScheme.surface,
                  context.colorScheme.primary,
                  .28,
                )!,
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(buildGauge(waiting: false));
      await tester.pumpAndSettle();
      expect(find.text('240.0'), findsOneWidget);

      final gaugeRect = tester.getRect(find.byType(SpeedTestGauge));
      final readoutRect = tester.getRect(
        find.descendant(
          of: find.byType(SpeedTestGauge),
          matching: find.byType(Column),
        ),
      );
      final pivotY = gaugeRect.top + gaugeRect.width / 2;
      expect(readoutRect.top - pivotY, greaterThan(20));

      await tester.pumpWidget(buildGauge(waiting: true));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('0.0'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('0.0'), findsOneWidget);

      await tester.pumpWidget(buildGauge(waiting: false));
      await tester.pumpAndSettle();
      expect(find.text('240.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
