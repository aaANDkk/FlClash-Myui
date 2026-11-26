import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/features/ip_quality/ip_quality_sheet.dart';
import 'package:fl_clash/features/ip_quality/ip_locate.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/features/ip_quality/risk_model.dart';
import 'package:fl_clash/features/ip_quality/risk_parser.dart';
import 'package:fl_clash/features/ip_quality/risk_provider.dart';
import 'package:fl_clash/features/ip_quality/risk_view.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/ui.dart' as app_ui;
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/glyph_finders.dart';

const sampleRisk = IpRisk(
  ip: '158.247.202.50',
  score: 28,
  level: IpRiskLevel.medium,
  country: 'South Korea',
  countryCode: 'KR',
  region: 'Seoul',
  city: 'Mapo-gu',
  organization: 'The Constant Company, LLC',
  asn: 'AS20473',
  hostname: '158.247.202.50.vultrusercontent.com',
  checks: [
    IpRiskCheck(group: IpRiskGroup.datacenter, name: 'Datacenter', hit: true),
    IpRiskCheck(
      group: IpRiskGroup.datacenter,
      name: 'Residential Proxy',
      hit: false,
    ),
    IpRiskCheck(group: IpRiskGroup.blacklist, name: 'Firehol', hit: false),
    IpRiskCheck(group: IpRiskGroup.blacklist, name: 'IP2ProxyLite', hit: false),
    IpRiskCheck(group: IpRiskGroup.blacklist, name: 'IPsum', hit: false),
    IpRiskCheck(group: IpRiskGroup.blacklist, name: 'Spamhaus', hit: false),
    IpRiskCheck(
      group: IpRiskGroup.blacklist,
      name: 'X4Bnet Spambot',
      hit: false,
    ),
    IpRiskCheck(group: IpRiskGroup.proxy, name: 'Anonymizing VPN', hit: false),
    IpRiskCheck(group: IpRiskGroup.proxy, name: 'Tor Exit Node', hit: false),
    IpRiskCheck(group: IpRiskGroup.proxy, name: 'Server', hit: true),
    IpRiskCheck(group: IpRiskGroup.proxy, name: 'Public Proxy', hit: false),
    IpRiskCheck(group: IpRiskGroup.proxy, name: 'Web Proxy', hit: false),
    IpRiskCheck(
      group: IpRiskGroup.proxy,
      name: 'Search Engine Robot',
      hit: false,
    ),
  ],
);

void main() {
  testWidgets('the IP card copies the address and shows a success banner', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        overrides: [
          ipLocateProvider.overrideWith(
            (_, ip) async => IpLocateInfo(ip: ip, asn: sampleRisk.asn),
          ),
          ipRiskProvider.overrideWith((_, ip) async => sampleRisk),
        ],
        child: const IpRiskSheet(ip: '158.247.202.50'),
      ),
    );
    await tester.pumpAndSettle();

    final l = tester.element(find.byType(IpRiskSheet)).appLocalizations;
    final copy = find.byTooltip(l.copy);
    expect(find.byTooltip(l.edit), findsNothing);
    expect(
      find.ancestor(of: copy, matching: find.byType(app_ui.MinIconButtonTheme)),
      findsOneWidget,
    );
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, sampleRisk.ip);
    expect(find.text(l.copySuccess), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unknown hosting mark shows a question, distinct from no', (
    tester,
  ) async {
    const risk = IpRisk(
      ip: '1.2.3.4',
      score: 20,
      level: IpRiskLevel.low,
      checks: [
        IpRiskCheck(group: IpRiskGroup.datacenter, name: 'Datacenter'),
        IpRiskCheck(
          group: IpRiskGroup.datacenter,
          name: 'Residential Proxy',
          hit: true,
        ),
        IpRiskCheck(group: IpRiskGroup.proxy, name: 'Server', hit: false),
      ],
    );
    await tester.pumpWidget(
      const TestApp(
        locale: Locale('en'),
        child: RiskChecksCard(risk: risk),
      ),
    );
    expect(find.byGlyph(AppGlyphs.helpCircle), findsOneWidget);
    expect(find.text('—'), findsNothing);
    expect(find.text('Datacenter'), findsOneWidget);
    expect(find.text('Premium Residential IP'), findsNothing);
  });
  setUpAll(() async {
    await (FontLoader(
      app_ui.FontFamily.twEmoji.value,
    )..addFont(rootBundle.load('assets/fonts/Twemoji.Mozilla.ttf'))).load();
    final font = File('.dart_tool/risk-preview-font.ttf');
    if (await font.exists()) {
      final loader = FontLoader('RiskPreview')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
    }
  });
  testWidgets('native IP replaces hosting flags and omits missing fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const home = IpRisk(
      ip: '1.2.3.4',
      score: 0,
      level: IpRiskLevel.low,
      isp: 'Example ISP',
      checks: [
        IpRiskCheck(group: IpRiskGroup.datacenter, name: 'Datacenter'),
        IpRiskCheck(
          group: IpRiskGroup.datacenter,
          name: 'Residential Proxy',
          hit: false,
        ),
        IpRiskCheck(group: IpRiskGroup.proxy, name: 'Server', hit: false),
      ],
    );
    expect(home.isHomeBroadband, isTrue);
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        overrides: [
          ipLocateProvider.overrideWith(
            (_, ip) async => IpLocateInfo(ip: ip, company: home.isp),
          ),
          ipRiskProvider(home.ip).overrideWith((_) async => home),
        ],
        child: const IpRiskSheet(ip: '1.2.3.4'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Premium Residential IP'), findsNWidgets(2));
    expect(find.text('Datacenter'), findsNothing);
    expect(find.text('Residential proxy'), findsNothing);
    expect(find.text('Hostname'), findsNothing);
    expect(find.text('Country / region'), findsNothing);
    expect(find.text('Organization / ASN'), findsNothing);
    expect(find.text('External blacklists'), findsNothing);
    expect(find.text('Example ISP'), findsOneWidget);
    expect(find.text('—'), findsNothing);
    final noteSpan = riskNoteMessage(
      tester.element(find.byType(IpRiskSheet)),
      const IpRisk(
        ip: '1.2.3.4',
        score: 12,
        level: IpRiskLevel.low,
        note: IpRiskNote(
          direct: false,
          isp: 'Source Network',
          amount: IpRiskAmount.medium,
          share: IpRiskShare.some,
          operatorName: 'Source Network',
          operatorLevel: IpRiskLevel.low,
          ownerName: 'Owner Network',
          ownerLevel: IpRiskLevel.high,
          connection: IpRiskConnection.vpn,
          warning: IpRiskLevel.high,
        ),
      ),
    );
    final note = noteSpan.toPlainText();
    final separators = (noteSpan as TextSpan).children!
        .whereType<TextSpan>()
        .where((span) => span.text == ' · ');
    expect(separators, hasLength(2));
    for (final separator in separators) {
      expect(
        separator.style!.color,
        tester.element(find.byType(IpRiskSheet)).colorScheme.onSurface,
      );
    }
    expect(note, contains('Source Network'));
    expect(note, contains('Owner Network'));
    expect(note, contains('12'));
    expect(note, contains('Anonymizing VPN'));
    expect(note, contains('fraudsters'));
    expect(
      find.ancestor(
        of: find.text('Source Scamalytics and IPLocate.io'),
        matching: find.byType(app_ui.ListFooter),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Source Scamalytics and IPLocate.io')).dx,
      greaterThan(tester.getTopLeft(find.byType(RiskScoreCard)).dx),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('IP details keeps hiding and has no toolbar refresh', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        overrides: [
          ipLocateProvider.overrideWith(
            (_, ip) async => IpLocateInfo(
              ip: ip,
              company: sampleRisk.organization,
              network: sampleRisk.isp,
              asn: sampleRisk.asn,
            ),
          ),
          ipRiskProvider(sampleRisk.ip).overrideWith((_) async => sampleRisk),
        ],
        child: const IpRiskSheet(ip: '158.247.202.50'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide IP'), findsOneWidget);
    expect(find.byTooltip('Check again'), findsNothing);
    expect(find.byGlyph(AppGlyphs.refresh), findsNothing);
    expect(find.text('Source Scamalytics and IPLocate.io'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Scamalytics parser preserves score, supplied risk and flags', () {
    final result = parseScamalytics('1.2.3.4', '''Fraud Score: 28
      <div class="panel_title">Medium Risk</div><table>
      <th class="title">Datacenter</th><th>Datacenter</th><td>Yes</td>
      <th>Residential Proxy</th><td>No</td>
      <th class="title">Proxies</th><th>Server</th><td>Yes</td>
      <th class="title">IP Address Information</th><th>Country Code</th><td>KR</td>
      <th>ASN</th><td>20473</td></table>''');
    expect(result!.score, 28);
    expect(result.level, IpRiskLevel.medium);
    expect(result.isDatacenter, isTrue);
    expect(result.asn, 'AS20473');
    expect(parseScamalytics('1.2.3.4', '<html>Access denied</html>'), isNull);
  });

  test('risk request uses Scamalytics and rejects blocked responses', () async {
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    var blocked = false;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.uri.toString(), 'https://scamalytics.com/ip/1.2.3.4');
          expect(options.responseType, ResponseType.bytes);
          handler.resolve(
            Response<List<int>>(
              requestOptions: options,
              data: utf8.encode(blocked ? 'Access denied' : 'Fraud Score: 28'),
              statusCode: 200,
            ),
          );
        },
      ),
    );
    expect((await fetchIpRisk(dio, '1.2.3.4', CancelToken())).score, 28);
    blocked = true;
    await expectLater(
      fetchIpRisk(dio, '1.2.3.4', CancelToken()),
      throwsFormatException,
    );
  });

  for (final scenario in [
    (width: 360.0, scale: 1.0, dark: false),
    (width: 430.0, scale: 1.0, dark: false),
    (width: 800.0, scale: 1.0, dark: false),
    (width: 360.0, scale: 1.5, dark: true),
  ]) {
    final (:width, :scale, :dark) = scenario;
    testWidgets('risk layout fits $scenario and preserves privacy', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const key = ValueKey('risk-preview');
      await tester.pumpWidget(
        TestApp(
          theme: app_ui.ThemeData(fontFamily: 'RiskPreview'),
          themeMode: dark ? app_ui.ThemeMode.dark : app_ui.ThemeMode.light,
          locale: const Locale('zh', 'CN'),
          homeBuilder: (child) => MediaQuery(
            data: MediaQueryData.fromView(
              tester.view,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child,
          ),
          overrides: [
            ipLocateProvider.overrideWith(
              (_, ip) async => IpLocateInfo(
                ip: ip,
                company: sampleRisk.organization,
                network: sampleRisk.isp,
                asn: sampleRisk.asn,
              ),
            ),
            ipRiskProvider(sampleRisk.ip).overrideWith((_) async => sampleRisk),
          ],
          child: const RepaintBoundary(
            key: key,
            child: IpRiskSheet(ip: '158.247.202.50'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(app_ui.NullStatusSwitcher), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect(find.text('数据中心'), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(RiskChecksCard),
          matching: find.text('数据中心'),
        ),
        findsOneWidget,
      );
      final sheetCtx = tester.element(find.byType(RiskChecksCard));
      final fireholPill = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Firehol'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (fireholPill.decoration as ShapeDecoration).color,
        DashboardColors.of(sheetCtx).tone,
      );
      expect(tester.widget<Text>(find.text('服务器')).style!.color, isNotNull);
      expect(find.byType(RiskScoreCard), findsOneWidget);
      final col = tester.widget<Column>(
        find
            .descendant(
              of: find.byType(RiskChecksCard),
              matching: find.byType(Column),
            )
            .first,
      );
      expect(col.crossAxisAlignment, CrossAxisAlignment.stretch);
      if (scale == 1.0) {
        final badgeFinder = find.byType(RiskLevelBadge);
        final badgeTextFinder = find.descendant(
          of: badgeFinder,
          matching: find.byType(Text),
        );
        expect(
          (tester.getCenter(badgeTextFinder).dy -
                  tester.getCenter(badgeFinder).dy)
              .abs(),
          lessThanOrEqualTo(0.5),
        );
        final datacenterText = find.descendant(
          of: find.byType(RiskChecksCard),
          matching: find.text('数据中心'),
        );
        final datacenterBox = find.ancestor(
          of: datacenterText,
          matching: find.byType(Container),
        );
        expect(
          (tester.getCenter(datacenterText).dy -
                  tester.getCenter(datacenterBox.first).dy)
              .abs(),
          lessThanOrEqualTo(0.5),
        );
      }
      final flagsHeaderTopLeft = tester.getTopLeft(
        find.descendant(
          of: find.byType(RiskChecksCard),
          matching: find.text('命中标记'),
        ),
      );
      final cardTopLeft = tester.getTopLeft(find.byType(RiskChecksCard));
      expect(flagsHeaderTopLeft.dy, greaterThan(cardTopLeft.dy));
      expect(
        tester.getTopLeft(find.text('机房或代理')).dy,
        greaterThan(flagsHeaderTopLeft.dy),
      );
      expect(
        find.descendant(
          of: find.byType(RiskChecksCard),
          matching: find.byType(app_ui.Divider),
        ),
        findsNWidgets(2),
      );
      expect(
        tester.getTopLeft(find.byType(IpAttributionCard)).dy,
        lessThan(tester.getTopLeft(find.byType(RiskChecksCard)).dy),
      );
      expect(
        tester.getTopLeft(find.byType(RiskScoreCard)).dy,
        lessThan(tester.getTopLeft(find.byType(IpAttributionCard)).dy),
      );
      expect(find.byGlyph(AppGlyphs.flag), findsOneWidget);
      expect(find.byGlyph(AppGlyphs.location), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 430) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '.dart_tool/ip-risk-preview.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final hideLabel = tester
          .element(find.byType(IpRiskSheet))
          .appLocalizations
          .hideIp;
      await tester.tap(find.byTooltip(hideLabel));
      await tester.pumpAndSettle();
      expect(find.text('158.247.202.50'), findsNothing);
      expect(find.text('158.247.202.50.vultrusercontent.com'), findsNothing);
      expect(find.text('主机名'), findsNothing);
      expect(find.text('*****.vultrusercontent.com'), findsNothing);
      expect(
        tester.widget<Text>(find.text('*****')).style!.fontFamily,
        app_ui.FontFamily.mapleMono.value,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'failed risk card retries inline without confirmation or layout changes',
    (tester) async {
      var attempts = 0;
      Completer<IpRisk>? retryCompleter;
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
            ipLocateProvider.overrideWith(
              (_, ip) async => IpLocateInfo(
                ip: ip,
                company: sampleRisk.organization,
                network: sampleRisk.isp,
                asn: sampleRisk.asn,
              ),
            ),
            ipRiskProvider(sampleRisk.ip).overrideWith((_) async {
              attempts++;
              if (attempts == 1) {
                throw const FormatException('unavailable');
              }
              return retryCompleter!.future;
            }),
          ],
          child: const IpRiskSheet(ip: '158.247.202.50'),
        ),
      );
      await tester.pumpAndSettle();

      final l = tester.element(find.byType(IpRiskSheet)).appLocalizations;
      expect(find.text(l.ipRiskFailed), findsOneWidget);
      expect(find.byGlyph(AppGlyphs.error), findsOneWidget);
      expect(find.widgetWithText(app_ui.FilledButton, l.retry), findsOneWidget);
      expect(find.byTooltip('Check again'), findsNothing);
      final errorCard = find.ancestor(
        of: find.text(l.ipRiskFailed),
        matching: find.byType(app_ui.Card),
      );
      final beforeRect = tester.getRect(errorCard);

      retryCompleter = Completer<IpRisk>();
      await tester.tap(find.widgetWithText(app_ui.FilledButton, l.retry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('158.247.202.50'), findsOneWidget);
      expect(find.text(l.ipRiskFailed), findsOneWidget);
      expect(tester.getRect(errorCard), beforeRect);
      expect(find.byType(app_ui.InputDialog), findsNothing);
      expect(find.byType(app_ui.ActivityIndicator), findsOneWidget);

      retryCompleter.complete(sampleRisk);
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text(l.ipRiskFailed), findsNothing);
      expect(find.byType(RiskScoreCard), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'instant retry failure holds inline loading without bouncing the error card',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
            ipLocateProvider.overrideWith(
              (_, ip) async => IpLocateInfo(
                ip: ip,
                company: sampleRisk.organization,
                network: sampleRisk.isp,
                asn: sampleRisk.asn,
              ),
            ),
            ipRiskProvider(sampleRisk.ip).overrideWith((_) async {
              attempts++;
              throw const FormatException('offline');
            }),
          ],
          child: const IpRiskSheet(ip: '158.247.202.50'),
        ),
      );
      await tester.pumpAndSettle();

      final l = tester.element(find.byType(IpRiskSheet)).appLocalizations;
      await tester.tap(find.widgetWithText(app_ui.FilledButton, l.retry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(attempts, 2);
      expect(find.text(l.ipRiskFailed), findsOneWidget);
      expect(find.byType(app_ui.ActivityIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text(l.ipRiskFailed), findsOneWidget);
      expect(find.widgetWithText(app_ui.FilledButton, l.retry), findsOneWidget);
      expect(find.byTooltip('Check again'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'location card mirrors IP lookup attribution styling with country pill and ASN row',
    (tester) async {
      const longRisk = IpRisk(
        ip: '58.247.1.2',
        score: 10,
        level: IpRiskLevel.low,
        country: 'China',
        countryCode: 'CN',
        region: 'Shanghai',
        city: 'Hongkou (Hongkou Qu)',
        organization: 'Shanghai Information Network Co., Ltd.',
        asn: 'AS4811',
        isp: 'China Unicom CHINA169 Zhejiang Province network',
      );
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
            ipLocateProvider.overrideWith(
              (_, ip) async => IpLocateInfo(
                ip: ip,
                company: longRisk.organization,
                network: longRisk.isp,
                asn: 'AS9999',
              ),
            ),
            ipRiskProvider(longRisk.ip).overrideWith((_) async => longRisk),
          ],
          child: const IpRiskSheet(ip: '58.247.1.2'),
        ),
      );
      await tester.pumpAndSettle();

      final sheetCtx = tester.element(find.byType(IpRiskSheet));
      final l = sheetCtx.appLocalizations;
      expect(find.text('Shanghai · Hongkou (Hongkou Qu)'), findsOneWidget);
      expect(find.text('CN'), findsOneWidget);
      expect(find.text(l.isp), findsOneWidget);
      expect(find.text(l.operatorOrAsn), findsNothing);
      expect(
        find.text('Shanghai Information Network Co., Ltd.'),
        findsOneWidget,
      );
      expect(find.textContaining('AS9999'), findsOneWidget);
      expect(find.textContaining(longRisk.isp), findsOneWidget);
      expect(find.textContaining('AS4811'), findsNothing);
      expect(find.text(l.unknown), findsOneWidget);
      final codePill = find
          .ancestor(
            of: find.text('CN'),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final codeBox = tester.widget<DecoratedBox>(codePill);
      expect(
        tester
            .getTopRight(find.text('Shanghai \u00b7 Hongkou (Hongkou Qu)'))
            .dx,
        closeTo(tester.getTopRight(codePill).dx, 1),
      );
      expect(
        (codeBox.decoration as ShapeDecoration).color,
        DashboardColors.of(sheetCtx).tone,
      );
      final countryFinder = find.byWidgetPredicate(
        (w) => w is app_ui.EmojiText && w.text == '🇨🇳 China',
      );
      expect(countryFinder, findsOneWidget);
      expect(find.byType(app_ui.Divider), findsNWidgets(2));
      expect(find.text('ASN'), findsOneWidget);
      expect(find.byGlyph(AppGlyphs.flag), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('CN')).dx,
        greaterThan(tester.getTopLeft(countryFinder).dx),
      );
      expect(
        tester.getTopLeft(find.text('CN')).dy,
        lessThan(tester.getTopLeft(countryFinder).dy),
      );
      expect(
        tester.getTopLeft(find.text('Shanghai · Hongkou (Hongkou Qu)')).dy,
        greaterThan(tester.getTopLeft(countryFinder).dy),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'proxyName resolves exit IP without showing node name and retries on failure',
    (tester) async {
      var exitAttempts = 0;
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
            ipLocateProvider.overrideWith(
              (_, ip) async => IpLocateInfo(
                ip: ip,
                company: sampleRisk.organization,
                network: sampleRisk.isp,
                asn: sampleRisk.asn,
              ),
            ),
            proxyExitIpProvider.overrideWith((_, proxy) async {
              expect(proxy, 'HK-01');
              exitAttempts++;
              if (exitAttempts == 1) {
                throw Exception('exit probe failed');
              }
              return sampleRisk.ip;
            }),
            ipRiskProvider(sampleRisk.ip).overrideWith((_) async => sampleRisk),
          ],
          child: const IpRiskSheet(proxyName: 'HK-01'),
        ),
      );
      await tester.pumpAndSettle();

      final sheetCtx = tester.element(find.byType(IpRiskSheet));
      final l = sheetCtx.appLocalizations;
      expect(exitAttempts, 1);
      expect(find.text('--'), findsOneWidget);
      expect(find.text('HK-01'), findsNothing);
      expect(find.text(l.ipRiskFailed), findsOneWidget);

      await tester.tap(find.widgetWithText(app_ui.FilledButton, l.retry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(exitAttempts, 2);
      expect(find.byGlyph(AppGlyphs.location), findsOneWidget);
      expect(find.text(sampleRisk.ip), findsOneWidget);
      expect(find.text('HK-01'), findsNothing);
      expect(find.text('${sampleRisk.displayScore}'), findsOneWidget);
      expect(find.text(l.ipRiskMedium), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
