import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/country_flags.dart';
import 'package:fl_clash/common/country_names.dart';
import 'package:fl_clash/features/ip_quality/ip_locate.dart';
import 'package:fl_clash/features/ip_quality/risk_model.dart';
import 'package:fl_clash/features/ip_quality/risk_view.dart';
import 'package:fl_clash/common/service_probe.dart'
    show directOutbound, routedOutbound;
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart' show CoreStatus;
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/features/ip_quality/risk_provider.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/views/dashboard/widgets/current_outbound.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/glyph_finders.dart';
import '../../helpers/test_app.dart';
import 'package:prism_ui/hct/hct.dart';
import 'package:prism_ui/prism_ui.dart';
import '../../helpers/host_scaffold.dart';

const _ip = '203.0.113.9';

const _profile = Profile(id: 1, autoUpdateDuration: Duration.zero);

const _residential = IpRisk(
  ip: _ip,
  score: 0,
  level: IpRiskLevel.low,
  organization: 'Example Broadband',
  asn: 'AS64500',
  checks: [
    IpRiskCheck(
      group: IpRiskGroup.datacenter,
      name: 'Residential Proxy',
      hit: true,
    ),
  ],
);

class _MockCore extends Mock implements CoreHandlerInterface {}

class _RecordingSetupAction extends SetupAction {
  final requests = <bool>[];

  @override
  Future<bool> setRunning(bool running, {bool initialize = false}) {
    requests.add(running);
    ref.read(runTimeProvider.notifier).value = running ? 1 : null;
    return Future.value(true);
  }
}

class _Ips extends OutboundIpProbe {
  @override
  RoutedProbeState<String, IpInfo> build() => const RoutedProbeState({
    routedOutbound: ProbeEntry(
      phase: ProbePhase.fresh,
      value: IpInfo(ip: _ip, countryCode: 'GB'),
    ),
  });

  @override
  void watch(String target) {}

  @override
  void unwatch(String target) {}
}

OutboundIpResult _address({int coreEpoch = 1}) => OutboundIpResult(
  url: 'https://www.cloudflare.com/cdn-cgi/trace',
  body: 'ip=$_ip\nloc=GB\n',
  coreEpoch: coreEpoch,
  routeVersion: 1,
);

Widget _card({DashboardDensity density = DashboardDensity.standard}) =>
    HostScaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: density.isDesktop ? 600 : 380,
          height: density.isDesktop ? 208 : null,
          child: DashboardDensityScope(
            density: density,
            scale: 1,
            child: const CurrentOutboundCard(),
          ),
        ),
      ),
    );

Widget _app(
  Future<IpRisk> Function(Ref ref, String ip) quality, {
  DashboardDensity density = DashboardDensity.standard,
  bool root = false,
  VoidCallback? onAttributionQuery,
}) {
  return TestApp(
    locale: const Locale('en'),
    overrides: [
      profilesProvider.overrideWithValue(const [_profile]),
      suspendProvider.overrideWithValue(false),
      rootAccessProvider.overrideWith((_) async => root),
      outboundIpProbeProvider.overrideWithBuild(
        (_, _) => const RoutedProbeState({
          routedOutbound: ProbeEntry(
            phase: ProbePhase.fresh,
            value: IpInfo(ip: _ip, countryCode: 'GB'),
          ),
        }),
      ),
      ipRiskProvider.overrideWith(quality),
      ipLocateProvider.overrideWith((_, ip) async {
        onAttributionQuery?.call();
        return IpLocateInfo(ip: ip, company: 'Example Broadband');
      }),
    ],
    child: _card(density: density),
  );
}

Widget _probingApp(
  CoreHandlerInterface core, {
  Future<IpRisk> Function(Ref ref, String ip)? quality,
}) {
  return TestApp(
    locale: const Locale('en'),
    overrides: [
      profilesProvider.overrideWithValue(const [_profile]),
      routeTrackerProvider.overrideWithBuild(
        (ref, _) => RouteState(
          coreEpoch: 1,
          routeVersion: 1,
          hostEpoch: 1,
          proxied: ref.watch(isStartProvider),
          synced: true,
          live: true,
        ),
      ),
      coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ipRiskProvider.overrideWith(quality ?? (_, _) async => _residential),
    ],
    child: _card(),
  );
}

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _clover() => find.ancestor(
  of: find.byType(CountryBadgeShape),
  matching: find.byWidgetPredicate((widget) => widget is PressRegion),
);

Finder _locationLabel(String text) => find.descendant(
  of: find
      .ancestor(
        of: find.byGlyph(AppGlyphs.location),
        matching: find.byType(Row),
      )
      .first,
  matching: find.text(text),
);

CountryBadgeShape _badgeShape(WidgetTester tester) =>
    tester.widget<CountryBadgeShape>(
      find.descendant(of: _clover(), matching: find.byType(CountryBadgeShape)),
    );

double _cloverTurn(WidgetTester tester) => _badgeShape(tester).rotation;

double _cloverMorph(WidgetTester tester) => _badgeShape(tester).morphProgress;

DashboardChip _chip(WidgetTester tester, String label) =>
    tester.widget<DashboardChip>(
      find.ancestor(of: find.text(label), matching: find.byType(DashboardChip)),
    );

void main() {
  setUpAll(() => registerFallbackValue(const OutboundIpParams(timeout: 0)));

  group('root access', () {
    if (rsFeature) {
      testWidgets('fades in a border and names it only to a screen reader', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_app((_, _) async => _residential, root: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        final midway = tester.widget<DashboardCard>(find.byType(DashboardCard));
        expect(midway.side.color.a, inExclusiveRange(0, 1));

        await tester.pump(commonDuration);

        final card = tester.widget<DashboardCard>(find.byType(DashboardCard));
        expect(card.side.color.a, closeTo(1, 0.01));
        expect(find.text('Root'), findsNothing);
        expect(find.bySemanticsLabel(RegExp('Status Root')), findsOneWidget);
        semantics.dispose();
      });
    }

    testWidgets('leaves the card plain without it', (tester) async {
      await tester.pumpWidget(_app((_, _) async => _residential));
      await tester.pump(commonDuration);

      final card = tester.widget<DashboardCard>(find.byType(DashboardCard));
      expect(card.side, BorderSide.none);
    });
  });

  group('the exit address', () {
    for (final running in [false, true]) {
      testWidgets('shows fraud score with running=$running', (tester) async {
        const home = IpRisk(
          ip: _ip,
          score: 0,
          level: IpRiskLevel.low,
          checks: [
            IpRiskCheck(group: IpRiskGroup.datacenter, name: 'Datacenter'),
          ],
        );
        await tester.pumpWidget(_app((_, _) async => home));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CurrentOutboundCard)),
        );
        container.read(runTimeProvider.notifier).value = running ? 1 : null;
        await tester.pump();
        expect(find.text('0 / 100'), findsOneWidget);
        expect(find.text('Low risk'), findsOneWidget);
        expect(find.byType(RiskLevelBadge), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('shows its country and fraud score', (tester) async {
      await tester.pumpWidget(_app((_, _) async => _residential));
      await tester.pump();

      expect(find.text(_ip), findsOneWidget);
      expect(_locationLabel('GB'), findsOneWidget);
      expect(find.text('1 / 100'), findsOneWidget);
      expect(find.text('Low risk'), findsOneWidget);
      expect(_chip(tester, 'Not running').tone, DashboardChipTone.idle);
      expect(find.text('Fraud score'), findsOneWidget);
      expect(find.text('Type'), findsNothing);
      expect(find.text('Status'), findsOneWidget);
      expect(find.byGlyph(AppGlyphs.refresh), findsNothing);
    });

    testWidgets('a little wider than its card shrinks to fit', (tester) async {
      await tester.pumpWidget(_app((_, _) async => _residential));
      await tester.pump();

      expect(tester.widget<Text>(find.text(_ip)).overflow, isNull);
      expect(
        find.ancestor(of: find.text(_ip), matching: find.byType(FittedBox)),
        findsOneWidget,
      );
    });

    testWidgets('keeps service status independent of the risk score', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          (_, _) async =>
              const IpRisk(ip: _ip, score: 95, level: IpRiskLevel.veryHigh),
        ),
      );
      await tester.pump();

      expect(_chip(tester, 'Not running').tone, DashboardChipTone.idle);
    });

    testWidgets(
      'shows colored score with muted denominator and outlined risk pill aligned with runtime',
      (tester) async {
        const risk = IpRisk(ip: _ip, score: 50, level: IpRiskLevel.medium);
        await tester.pumpWidget(_app((_, _) async => risk));
        await tester.pump();
        final scoreColor = riskScoreColor(50);
        final score = tester.widget<Text>(find.text('50 / 100'));
        final spans = (score.textSpan! as TextSpan).children!.cast<TextSpan>();
        expect(spans.first.text, '50');
        expect(spans.first.style!.color, scoreColor);
        expect(spans.last.text, ' / 100');
        expect(spans.last.style!.color, isNot(scoreColor));
        final level = tester.widget<Text>(find.text('Medium risk'));
        expect(level.style!.color, scoreColor);
        final pill = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text('Medium risk'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = pill.decoration as ShapeDecoration;
        expect(decoration.color, isNull);
        final border = decoration.shape as RoundedSuperellipseBorder;
        expect(border.side.width, 1);
        expect(
          border.side.color.toARGB32() & 0x00FFFFFF,
          scoreColor.toARGB32() & 0x00FFFFFF,
        );
        final runtimeRect = tester.getRect(find.text('00:00:00'));
        final scoreRect = tester.getRect(find.text('50 / 100'));
        expect(scoreRect.top, closeTo(runtimeRect.top, 0.5));
        expect(scoreRect.height, closeTo(runtimeRect.height, 0.5));
        expect(find.byType(RiskLevelBadge), findsNothing);
        expect(find.text('Type'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('keeps score unavailable when the risk request fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app((_, _) async => throw StateError('unavailable')),
      );
      await tester.pump();

      expect(_locationLabel('GB'), findsOneWidget);
      expect(find.text('Not running'), findsOneWidget);
      expect(_chip(tester, 'Not running').tone, DashboardChipTone.idle);
      expect(find.byType(DashboardChip), findsNWidgets(1));
      expect(find.text('Example Broadband'), findsNothing);
    });

    testWidgets('holds the place of its quality while it loads', (
      tester,
    ) async {
      final quality = Completer<IpRisk>();
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
            profilesProvider.overrideWithValue(const [_profile]),
            suspendProvider.overrideWithValue(false),
            outboundIpProbeProvider.overrideWith(_Ips.new),
            ipRiskProvider.overrideWith((_, _) => quality.future),
          ],
          child: _card(),
        ),
      );
      await tester.pump();

      expect(find.byType(SkeletonPill), findsNWidgets(2));
      expect(find.byType(SkeletonText), findsNWidgets(2));
      expect(tester.widget<PressRegion>(_clover()).onTap, isNull);
      expect(_cloverMorph(tester), closeTo(1, 1e-6));
      final turn = _cloverTurn(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_cloverTurn(tester), isNot(turn));

      quality.complete(_residential);
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonPill), findsNothing);
      expect(find.text('1 / 100'), findsOneWidget);
      expect(find.text('Low risk'), findsOneWidget);
      expect(_cloverMorph(tester), closeTo(0, 1e-6));
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(_cloverTurn(tester) % (math.pi / 2), closeTo(0, 1e-9));
      expect(tester.widget<PressRegion>(_clover()).onTap, isNotNull);
    });

    testWidgets('checks a failed quality again from its clover', (
      tester,
    ) async {
      final core = _MockCore();
      when(() => core.outboundIp(any())).thenAnswer((_) async => _address());
      var calls = 0;
      await tester.pumpWidget(
        _probingApp(
          core,
          quality: (_, _) async {
            calls++;
            throw StateError('unavailable');
          },
        ),
      );
      await tester.pump();
      await tester.pump(commonDuration);
      expect(find.text('Not running'), findsOneWidget);

      await tester.tap(find.byTooltip('Retry'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      verify(() => core.outboundIp(any())).called(2);
    });

    testWidgets('keeps organization and ASN in the details sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          (_, _) async =>
              const IpRisk(ip: _ip, score: 0, level: IpRiskLevel.low),
        ),
      );
      await tester.pump();

      expect(find.text('AS64500'), findsNothing);
    });

    testWidgets(
      'shows location pin with country name below IP and full country-region-city tooltip from ipRiskProvider',
      (tester) async {
        const located = IpRisk(
          ip: _ip,
          score: 10,
          level: IpRiskLevel.low,
          country: 'China',
          countryCode: 'CN',
          region: 'Shanghai',
          city: 'Hongkou (Hongkou Qu)',
        );
        await tester.pumpWidget(_app((_, _) async => located));
        await tester.pump();

        expect(find.byGlyph(AppGlyphs.location), findsOneWidget);
        expect(find.text('China'), findsOneWidget);
        expect(_locationLabel('CN'), findsNothing);
        final cardContext = tester.element(find.byType(CurrentOutboundCard));
        final stoppedColor = cardContext.colorScheme.onSurfaceVariant;
        expect(
          tester.widget<Text>(find.text('China')).style!.color,
          stoppedColor,
        );
        expect(
          tester.widget<GlyphIcon>(find.byGlyph(AppGlyphs.location)).color,
          stoppedColor,
        );
        expect(
          tester.getTopLeft(find.text(_ip)).dy,
          lessThan(tester.getTopLeft(find.text('China')).dy),
        );
        final container = ProviderScope.containerOf(cardContext);
        container.read(runTimeProvider.notifier).value = 1;
        await tester.pump();
        final runningColor = cardContext.colorScheme.onSurface;
        expect(
          tester.widget<Text>(find.text('China')).style!.color,
          runningColor,
        );
        expect(
          tester.widget<GlyphIcon>(find.byGlyph(AppGlyphs.location)).color,
          runningColor,
        );
        expect(countryFlagTone('TW'), CountryFlagTone.blue);
        expect(localizedCountryName('CN', const Locale('zh')), '中华人民共和国');
        expect(localizedCountryName('US', const Locale('zh')), '美利坚合众国');
        expect(localizedCountryName('TW', const Locale('zh')), '中国台湾省');
        expect(localizedCountryName('HK', const Locale('zh')), '香港特别行政区');
        expect(localizedCountryName('MO', const Locale('zh')), '澳门特别行政区');
        expect(localizedCountryName('GB', const Locale('zh')), '大不列颠联合王国');
        expect(localizedCountryName('JP', const Locale('zh')), '东瀛樱花国');
        expect(localizedCountryName('KR', const Locale('zh')), '宇宙起源泡菜国');
        expect(localizedCountryName('CA', const Locale('zh')), '加拿大枫叶之国');
        expect(localizedCountryName('MY', const Locale('zh')), '马来西亚联邦');
        expect(localizedCountryName('IL', const Locale('zh')), '圣城之地以色列');
        expect(localizedCountryName('IN', const Locale('zh')), '干净卫生恒河国');
        expect(localizedCountryName('TH', const Locale('zh')), '萨瓦迪卡泰王国');
        expect(localizedCountryName('NZ', const Locale('zh')), '中土世界新西兰');
        expect(localizedCountryName('SG', const Locale('zh')), '花园城市新加坡');
        expect(localizedCountryName('PH', const Locale('zh')), '南洋碰瓷香蕉国');
        expect(localizedCountryName('CN', const Locale('en')), isNull);
        expect(localizedCountryName('US', const Locale('en')), isNull);
        expect(localizedCountryName('JP', const Locale('ja')), '日本国');
        expect(localizedCountryName('KR', const Locale('ko')), '대한민국');
        expect(
          localizedCountryName('RU', const Locale('ru')),
          'Российская Федерация',
        );
        expect(
          find.byTooltip(
            '\u{1F1E8}\u{1F1F3} China \u00b7 Shanghai \u00b7 Hongkou (Hongkou Qu)',
          ),
          findsOneWidget,
        );
        expect(countryFlagTone('JP'), CountryFlagTone.grey);
        expect(countryFlagTone('KR'), CountryFlagTone.grey);
        expect(countryFlagTone('HK'), CountryFlagTone.red);
        expect(countryFlagTone('GB'), CountryFlagTone.red);
        expect(countryFlagTone('QA'), CountryFlagTone.red);
        expect(countryFlagTone('US'), CountryFlagTone.red);
        expect(countryFlagTone('MY'), CountryFlagTone.red);
        expect(countryFlagTone('LR'), CountryFlagTone.red);
        expect(countryFlagTone('PR'), CountryFlagTone.red);
        expect(countryFlagTone('FR'), CountryFlagTone.blue);
        expect(countryFlagTone('RU'), CountryFlagTone.blue);
        expect(countryFlagTone('SE'), CountryFlagTone.blue);
        expect(countryFlagTone('IT'), CountryFlagTone.green);
        expect(countryFlagTone('MX'), CountryFlagTone.green);
        expect(countryFlagTone('MR'), CountryFlagTone.green);
        expect(countryFlagTone('BG'), CountryFlagTone.green);
        expect(countryFlagTone('IR'), CountryFlagTone.green);
        expect(countryFlagTone('MO'), CountryFlagTone.green);
        expect(countryFlagTone('CO'), CountryFlagTone.yellow);
        final monoScheme = seededColorScheme(
          seedColor: const Color(0xFFFF3B4A),
          brightness: Brightness.light,
          style: ColorStyle.monochrome,
        );
        final monoRed = countryFlagRingColors(
          CountryFlagTone.red,
          monoScheme,
          ColorStyle.monochrome,
        );
        final monoBlue = countryFlagRingColors(
          CountryFlagTone.blue,
          monoScheme,
          ColorStyle.monochrome,
        );
        expect(monoRed.ring, monoBlue.ring);
        final vividScheme = seededColorScheme(
          seedColor: const Color(0xFFFF3B4A),
          brightness: Brightness.light,
          style: ColorStyle.vivid,
        );
        final vividRed = countryFlagRingColors(
          CountryFlagTone.red,
          vividScheme,
          ColorStyle.vivid,
        );
        final softScheme = seededColorScheme(
          seedColor: const Color(0xFFFF3B4A),
          brightness: Brightness.light,
          style: ColorStyle.soft,
        );
        final softRed = countryFlagRingColors(
          CountryFlagTone.red,
          softScheme,
          ColorStyle.soft,
        );
        expect(vividRed.ring, isNot(softRed.ring));
        expect(vividRed.innerGlow.a, closeTo(vividRed.glow.a * 0.55, 0.01));
        final monoOverlay = countryFlagOverlayStyle(
          monoScheme,
          ColorStyle.monochrome,
        );
        expect(monoOverlay.colorMatrix, hasLength(20));
        expect(monoOverlay.tintVeil.a, 0);
        final tintedScheme = seededColorScheme(
          seedColor: const Color(0xFFFF3B4A),
          brightness: Brightness.dark,
          style: ColorStyle.tinted,
        );
        final tintedOverlay = countryFlagOverlayStyle(
          tintedScheme,
          ColorStyle.tinted,
        );
        expect(tintedOverlay.tintVeil.a, greaterThan(0));
        expect(tintedOverlay.colorMatrix[0], lessThan(0.9));
        final sameToneSeeds = <Color>[
          const Color(0xFF77D5FF),
          const Color(0xFFADCAFF),
          const Color(0xFFC4C4FF),
          const Color(0xFFDEBBFF),
          const Color(0xFFE6C900),
          const Color(0xFF00E93D),
        ];
        for (final style in ColorStyle.values) {
          for (final brightness in Brightness.values) {
            final baseSeed = sameToneSeeds.first;
            final baseScheme = seededColorScheme(
              seedColor: baseSeed,
              brightness: brightness,
              style: style,
            );
            for (final tone in CountryFlagTone.values) {
              final expected = countryFlagRingColors(
                tone,
                baseScheme,
                style,
                seedColor: baseSeed,
              );
              expect(expected.ring.a, 1.0);
              final expectedHct = Hct.fromInt(expected.ring.toARGB32());
              expect(expectedHct.chroma, lessThanOrEqualTo(40.0));
              if (style == ColorStyle.tinted && tone == CountryFlagTone.grey) {
                expect(expectedHct.chroma, greaterThan(2.0));
                continue;
              }
              for (final otherSeed in sameToneSeeds.skip(1)) {
                final otherScheme = seededColorScheme(
                  seedColor: otherSeed,
                  brightness: brightness,
                  style: style,
                );
                final actual = countryFlagRingColors(
                  tone,
                  otherScheme,
                  style,
                  seedColor: otherSeed,
                );
                final actualHct = Hct.fromInt(actual.ring.toARGB32());
                expect(actualHct.hue, closeTo(expectedHct.hue, 2.5));
                expect(actualHct.tone, closeTo(expectedHct.tone, 0.5));
                expect(actualHct.chroma, closeTo(expectedHct.chroma, 1.5));
              }
            }
          }
        }
        final navySeed = const Color(0xFF003B76);
        final navyScheme = seededColorScheme(
          seedColor: navySeed,
          brightness: Brightness.light,
          style: ColorStyle.vivid,
        );
        final navyBlue = countryFlagRingColors(
          CountryFlagTone.blue,
          navyScheme,
          ColorStyle.vivid,
          seedColor: navySeed,
        );
        final navyHct = Hct.fromInt(navyBlue.ring.toARGB32());
        expect(navyHct.tone, lessThan(70));
      },
    );

    testWidgets('fits a phone', (tester) async {
      await tester.pumpWidget(
        _app((_, _) async => _residential, density: DashboardDensity.mobile),
      );
      await tester.pump();

      expect(find.text(_ip), findsOneWidget);
      expect(find.text('1 / 100'), findsOneWidget);
      expect(find.text('Low risk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens its details from the address, not the card', (
      tester,
    ) async {
      _useTallView(tester);
      var attributionQueries = 0;
      await tester.pumpWidget(
        _app(
          (_, _) async => _residential,
          onAttributionQuery: () => attributionQueries++,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Fraud score'));
      await tester.pumpAndSettle();
      expect(attributionQueries, 0);

      await tester.tap(find.text(_ip));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(RiskScoreCard),
          matching: find.text('Fraud score'),
        ),
        findsOneWidget,
      );
      expect(attributionQueries, 1);
      expect(find.text('Source Scamalytics and IPLocate.io'), findsOneWidget);
      expect(find.text('Residential proxy'), findsNWidgets(2));
    });

    testWidgets('opens its details from the country label too', (tester) async {
      _useTallView(tester);
      await tester.pumpWidget(_app((_, _) async => _residential));
      await tester.pump();

      await tester.tap(_locationLabel('GB'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(RiskScoreCard),
          matching: find.text('Fraud score'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('reports a source failure and checks again', (tester) async {
      _useTallView(tester);
      var calls = 0;
      await tester.pumpWidget(
        _app((_, _) async {
          calls++;
          throw StateError('unavailable');
        }),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Outbound IP details'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't load IP information. Try again."),
        findsOneWidget,
      );

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(calls, 2);
    });

    testWidgets('is masked everywhere once hidden', (tester) async {
      _useTallView(tester);
      await tester.pumpWidget(_app((_, _) async => _residential));
      await tester.pump();

      await tester.tap(find.byTooltip('Outbound IP details'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hide IP'));
      await tester.pumpAndSettle();

      expect(find.text(_ip), findsNothing);
      expect(find.text('*****'), findsNWidgets(2));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CurrentOutboundCard)),
      );
      expect(container.read(appSettingProvider).hideIp, isTrue);
    });

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(CurrentOutboundCard)),
        );

    void start(WidgetTester tester) {
      containerOf(tester).read(runTimeProvider.notifier).value = 1;
    }

    ProbePhase phaseOf(WidgetTester tester) => containerOf(
      tester,
    ).read(outboundIpProbeProvider).entryOf(routedOutbound).phase;

    Future<void> startProxy(WidgetTester tester) async {
      start(tester);
      await tester.pump();
      await tester.pump(probeMoveSettleDuration);
      await tester.pump();
    }

    testWidgets('that fails once keeps checking for a second answer', (
      tester,
    ) async {
      final core = _MockCore();
      var failing = true;
      when(() => core.outboundIp(any())).thenAnswer((invocation) async {
        final params =
            invocation.positionalArguments.single as OutboundIpParams;
        if (params.proxyName != directOutbound && failing) {
          throw TimeoutException('no answer');
        }
        return _address();
      });
      await tester.pumpWidget(_probingApp(core));
      await tester.pump();
      await tester.pump(commonDuration);
      expect(find.text(_ip), findsOneWidget);

      await startProxy(tester);
      expect(phaseOf(tester), ProbePhase.probing);
      expect(find.text('Check failed'), findsNothing);
      expect(find.byType(SkeletonText), findsNWidgets(3));

      failing = false;
      await tester.pump(probeConfirmDelay);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text(_ip), findsOneWidget);
      expect(find.byType(SkeletonText), findsNothing);
    });

    testWidgets('that fails twice is shown, then asked again behind it', (
      tester,
    ) async {
      final core = _MockCore();
      final asked = <String>[];
      const failing = true;
      when(() => core.outboundIp(any())).thenAnswer((invocation) async {
        final params =
            invocation.positionalArguments.single as OutboundIpParams;
        asked.add(params.proxyName);
        if (params.proxyName != directOutbound && failing) {
          throw TimeoutException('no answer');
        }
        return _address();
      });
      await tester.pumpWidget(_probingApp(core));
      await tester.pump();
      await tester.pump(commonDuration);

      await startProxy(tester);
      await tester.pump(probeConfirmDelay);
      await tester.pumpAndSettle();
      expect(find.text('Check failed'), findsOneWidget);
      expect(find.text('Tap the icon to retry'), findsNothing);
      expect(asked, [directOutbound, routedOutbound, routedOutbound]);
      await tester.tap(find.byTooltip('Retry'));
      await tester.pump();
      expect(asked, hasLength(4));
      await tester.pumpAndSettle();
      expect(find.text('Check failed'), findsOneWidget);

      await tester.pump(const Duration(minutes: 1));
      expect(asked, hasLength(4));
    });

    testWidgets('that timed out is shown without a second attempt', (
      tester,
    ) async {
      final core = _MockCore();
      when(() => core.outboundIp(any())).thenAnswer((invocation) async {
        final params =
            invocation.positionalArguments.single as OutboundIpParams;
        return params.proxyName == directOutbound
            ? _address()
            : const OutboundIpResult(
                error: 'timeout',
                coreEpoch: 1,
                routeVersion: 1,
              );
      });
      await tester.pumpWidget(_probingApp(core));
      await tester.pump();
      await tester.pump(commonDuration);

      await startProxy(tester);
      await tester.pump(commonDuration);
      expect(find.text('Check failed'), findsOneWidget);
    });
  });

  group('the start button', () {
    late ProviderContainer container;

    ProviderContainer containerWith({
      List<Profile> profiles = const [_profile],
      bool suspended = false,
    }) => ProviderContainer(
      overrides: [
        initProvider.overrideWithBuild((_, _) => true),
        profilesProvider.overrideWithValue(profiles),
        outboundIpProbeProvider.overrideWith(_Ips.new),
        ipRiskProvider.overrideWith((_, _) async => _residential),
        setupActionProvider.overrideWith(_RecordingSetupAction.new),
        suspendProvider.overrideWithValue(suspended),
      ],
    );

    tearDown(() => container.dispose());

    Future<void> pumpCard(
      WidgetTester tester, {
      DashboardDensity density = DashboardDensity.standard,
      bool glass = false,
    }) async {
      globalState.container = container;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            child: LiquidGlassScope(
              enabled: glass,
              child: _card(density: density),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Finder startButton() =>
        find.byWidgetPredicate((widget) => widget is PressRegion).last;

    testWidgets('dispatches each toggle through the shared running state', (
      tester,
    ) async {
      container = containerWith();
      container.read(runTimeProvider.notifier).value = 1;
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await pumpCard(tester);
      final action =
          container.read(setupActionProvider.notifier) as _RecordingSetupAction;

      await tester.tap(startButton());
      expect(action.requests, [false]);
      expect(container.read(isStartProvider), isFalse);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Start'), findsOneWidget);

      await tester.tap(startButton());
      expect(action.requests, [false, true]);
      expect(container.read(isStartProvider), isTrue);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Stop'), findsOneWidget);
    });

    testWidgets('a suspended tunnel swaps in the Wi-Fi off glyph and says so', (
      tester,
    ) async {
      container = containerWith(suspended: true);
      container.read(runTimeProvider.notifier).value = 1;
      await pumpCard(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(CurrentOutboundCard));
      expect(
        find.byTooltip(context.appLocalizations.suspended),
        findsOneWidget,
      );
      expect(find.text(context.appLocalizations.suspended), findsOneWidget);
      expect(find.byGlyph(AppGlyphs.wifiOff), findsOneWidget);
    });

    testWidgets('swells under a press and on glass bends within its shape', (
      tester,
    ) async {
      container = containerWith();
      container.read(runTimeProvider.notifier).value = 1;
      await pumpCard(tester, glass: true);
      await tester.pumpAndSettle();
      final glass = tester.widget<LiquidGlass>(
        find.descendant(of: startButton(), matching: find.byType(LiquidGlass)),
      );
      expect(glass.clipper, isNotNull);

      final press = find.descendant(
        of: startButton(),
        matching: find.byType(ElasticPress),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(startButton()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.renderObject(press).debugLayer, isA<TransformLayer>());
      await gesture.cancel();
      await tester.pumpAndSettle();
    });

    testWidgets('is off without a profile', (tester) async {
      container = containerWith(profiles: const []);
      await pumpCard(tester, density: DashboardDensity.mobile);

      final toggle = tester.widget<PressRegion>(startButton());
      expect(toggle.onTap, isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
