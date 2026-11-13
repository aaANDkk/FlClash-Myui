import 'package:fl_clash/features/traffic_stats/client.dart';
import 'package:fl_clash/features/traffic_stats/settings.dart';
import 'package:fl_clash/features/traffic_stats/store.dart';
import 'package:fl_clash/features/traffic_stats/view.dart';
import 'package:fl_clash/features/traffic_stats/widgets.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart' as app_ui;
import 'package:fl_clash/views/tools.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

class _MemoryTrafficStatsStore extends TrafficStatsSettingsStore {
  _MemoryTrafficStatsStore([this._initial = const TrafficStatsSettings()]);

  final TrafficStatsSettings _initial;

  @override
  Future<TrafficStatsSettings> build() async => _initial;

  @override
  Future<void> updateSettings(
    TrafficStatsSettings Function(TrafficStatsSettings current) update,
  ) async {
    final current = state.value ?? _initial;
    state = AsyncData(update(current));
  }
}

class _FakeTrafficStatsClient implements TrafficStatsClient {
  _FakeTrafficStatsClient({TrafficStatsResult? result})
    : result = result ?? const TrafficStatsResult();

  TrafficStatsResult result;
  final List<(String start, String end)> queries = [];
  int clearCalls = 0;

  @override
  Future<void> configure(
    TrafficStatsSettings settings, {
    required String profile,
    required int tzOffset,
    bool? screenOn,
    bool? suspended,
  }) async {}

  @override
  Future<TrafficStatsResult> getStats({
    required String start,
    required String end,
    int top = 50,
  }) async {
    queries.add((start, end));
    return result;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    result = const TrafficStatsResult();
  }
}

TrafficStatsResult _sampleResult() => TrafficStatsResult(
  up: 400 * 1024 * 1024,
  down: 1600 * 1024 * 1024,
  proxyUp: 300 * 1024 * 1024,
  proxyDown: 1200 * 1024 * 1024,
  series: [
    for (var h = 0; h < 24; h++)
      TrafficStatsPoint(
        label: h.toString().padLeft(2, '0'),
        up: h == 10 ? 120 * 1024 * 1024 : 10 * 1024 * 1024,
        down: h == 10 ? 500 * 1024 * 1024 : 40 * 1024 * 1024,
      ),
  ],
  hosts: const [
    TrafficStatsItem(
      name: 'example.com',
      up: 200 * 1024 * 1024,
      down: 900 * 1024 * 1024,
    ),
    TrafficStatsItem(
      name: 'cdn.example.net',
      up: 50 * 1024 * 1024,
      down: 300 * 1024 * 1024,
    ),
  ],
  processes: const [
    TrafficStatsItem(
      name: 'chrome.exe',
      up: 150 * 1024 * 1024,
      down: 800 * 1024 * 1024,
    ),
  ],
  nodes: const [
    TrafficStatsItem(
      name: '🇭🇰 Hong Kong 01',
      up: 300 * 1024 * 1024,
      down: 1200 * 1024 * 1024,
    ),
  ],
  profiles: const [
    TrafficStatsItem(
      name: 'Primary Profile',
      up: 400 * 1024 * 1024,
      down: 1600 * 1024 * 1024,
    ),
  ],
  rules: const [
    TrafficStatsItem(
      name: 'GEOSITE:google',
      up: 100 * 1024 * 1024,
      down: 500 * 1024 * 1024,
      hits: 42,
    ),
    TrafficStatsItem(
      name: 'MATCH',
      up: 50 * 1024 * 1024,
      down: 200 * 1024 * 1024,
      hits: 18,
    ),
  ],
  ruleHits: 60,
  since: '2026-11-01',
);

Widget _app(
  _FakeTrafficStatsClient client, {
  TrafficStatsSettings settings = const TrafficStatsSettings(),
  Locale locale = const Locale('en'),
  Widget page = const TrafficStatsView(),
}) => TestApp(
  locale: locale,
  overrides: [
    trafficStatsClientProvider.overrideWithValue(client),
    trafficStatsStoreProvider.overrideWith(
      () => _MemoryTrafficStatsStore(settings),
    ),
    appVisibleProvider.overrideWithValue(true),
    moreToolsSelectorStateProvider.overrideWithValue(
      const MoreToolsSelectorState(navigationItems: []),
    ),
  ],
  child: page,
);

void _setScreen(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  test(
    'date range and stepping helpers compute day, week, and month cleanly',
    () {
      final anchor = DateTime(2026, 11, 11); // Wednesday
      expect(trafficStatsDateRange(TrafficStatsPeriod.day, anchor), (
        '2026-11-11',
        '2026-11-11',
      ));
      expect(trafficStatsDateRange(TrafficStatsPeriod.week, anchor), (
        '2026-11-09',
        '2026-11-15',
      ));
      expect(trafficStatsDateRange(TrafficStatsPeriod.month, anchor), (
        '2026-11-01',
        '2026-11-30',
      ));
      expect(
        trafficStatsStepAnchor(TrafficStatsPeriod.month, anchor, -1),
        DateTime(2026, 10, 1),
      );
      expect(
        trafficStatsCanStepForward(
          TrafficStatsPeriod.day,
          DateTime(2026, 11, 10),
          DateTime(2026, 11, 11),
        ),
        isTrue,
      );
      expect(
        trafficStatsCanStepForward(
          TrafficStatsPeriod.day,
          DateTime(2026, 11, 11),
          DateTime(2026, 11, 11),
        ),
        isFalse,
      );
    },
  );

  testWidgets('ToolsView includes Traffic Statistics entry', (tester) async {
    _setScreen(tester, 430, 840);
    final client = _FakeTrafficStatsClient();
    await tester.pumpWidget(_app(client, page: const ToolsView()));
    await tester.pumpAndSettle();
    expect(find.text('Traffic Statistics'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'disabled empty state renders prompt card and enables collection on tap',
    (tester) async {
      _setScreen(tester, 360, 720);
      final client = _FakeTrafficStatsClient();
      await tester.pumpWidget(_app(client));
      await tester.pumpAndSettle();

      expect(find.byType(TrafficStatsDisabledCard), findsOneWidget);
      expect(find.text('Enable Traffic Statistics'), findsOneWidget);

      await tester.tap(find.text('Enable Traffic Statistics'));
      await tester.pumpAndSettle();

      expect(find.byType(TrafficStatsDisabledCard), findsNothing);
      expect(find.byType(TrafficStatsOverviewCard), findsOneWidget);
      expect(find.byType(TrafficStatsTrendCard), findsOneWidget);
      expect(client.queries.length, greaterThanOrEqualTo(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in [
    const Size(360, 720),
    const Size(430, 840),
    const Size(1080, 820),
  ]) {
    testWidgets(
      'populated dashboard lays out cleanly at ${size.width.toInt()}x${size.height.toInt()} and does not open sheet on domain tap',
      (tester) async {
        _setScreen(tester, size.width, size.height);
        final client = _FakeTrafficStatsClient(result: _sampleResult());
        await tester.pumpWidget(
          _app(
            client,
            settings: const TrafficStatsSettings(enable: true, siteIcon: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TrafficStatsOverviewCard), findsOneWidget);
        expect(find.byType(TrafficStatsTrendCard), findsOneWidget);
        expect(find.byType(TrafficStatsRuleHitsSection), findsOneWidget);
        expect(find.text('GEOSITE:google'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byType(TrafficStatsRankingSection),
          200,
          scrollable: find
              .descendant(
                of: find.byType(TrafficStatsView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.byType(TrafficStatsRankingSection), findsOneWidget);
        expect(find.text('example.com'), findsOneWidget);

        // Domain tap must NOT open a detail sheet or route.
        await Scrollable.ensureVisible(
          tester.element(find.text('example.com')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        final domainCenter = tester.getCenter(find.text('example.com'));
        expect((Offset.zero & size).contains(domainCenter), isTrue);
        await tester.tapAt(domainCenter);
        await tester.pumpAndSettle();
        expect(find.byType(TrafficStatsView), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Switch ranking tabs: Process -> Node -> Profile -> Domain.
        await Scrollable.ensureVisible(
          tester.element(find.text('Process')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Process'));
        await tester.pumpAndSettle();
        expect(find.text('chrome.exe'), findsOneWidget);

        await tester.tap(find.text('Node'));
        await tester.pumpAndSettle();
        expect(find.text('🇭🇰 Hong Kong 01'), findsOneWidget);

        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(find.text('Primary Profile'), findsOneWidget);

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('settings sheet opens, updates preferences, and clears data', (
    tester,
  ) async {
    _setScreen(tester, 430, 840);
    final client = _FakeTrafficStatsClient(result: _sampleResult());
    await tester.pumpWidget(
      _app(
        client,
        settings: const TrafficStatsSettings(enable: true, siteIcon: false),
      ),
    );
    await tester.pumpAndSettle();

    final settingsBtn = find.byWidgetPredicate(
      (w) => w is GlyphIcon && w.glyph == AppGlyphs.sliders,
    );
    await tester.tap(settingsBtn);
    await tester.pumpAndSettle();

    expect(find.byType(TrafficStatsSettingsView), findsOneWidget);
    expect(find.text('Detailed Breakdown'), findsOneWidget);
    await tester.tap(find.text('Detailed Breakdown').hitTestable());
    await tester.pumpAndSettle();
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(TrafficStatsSettingsView)),
      ).read(trafficStatsStoreProvider).value!.detail,
      isFalse,
    );
    await tester.scrollUntilVisible(
      find.text('Clear data'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(TrafficStatsSettingsView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Clear data')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear data'), findsOneWidget);

    await tester.tap(find.text('Clear data').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(app_ui.AlertDialog), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(app_ui.AlertDialog),
            matching: find.text('Clear data'),
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(client.clearCalls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
