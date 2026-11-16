import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/features/ip_quality/ip_quality_sheet.dart';
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
  testWidgets('only the small edit button opens and updates the IP', (
    tester,
  ) async {
    final queried = <String>[];
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        overrides: [
          ipRiskProvider.overrideWith((_, ip) async {
            queried.add(ip);
            return IpRisk(ip: ip, score: 0, level: IpRiskLevel.low);
          }),
        ],
        child: const IpRiskSheet(ip: '158.247.202.50'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('158.247.202.50'));
    await tester.pumpAndSettle();
    expect(find.byType(app_ui.InputDialog), findsNothing);
    final edit = find.byTooltip('Edit');
    expect(
      find.ancestor(of: edit, matching: find.byType(app_ui.MinIconButtonTheme)),
      findsOneWidget,
    );
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.byType(app_ui.InputDialog), findsOneWidget);
    final submit = tester
        .element(find.byType(app_ui.InputDialog))
        .appLocalizations
        .submit;
    await tester.enterText(find.byType(EditableText), '192.168.1.1');
    await tester.tap(find.text(submit));
    await tester.pumpAndSettle();
    expect(find.byType(app_ui.InputDialog), findsOneWidget);
    expect(queried, ['158.247.202.50']);
    await tester.enterText(find.byType(EditableText), '8.8.8.8');
    await tester.tap(find.text(submit));
    await tester.pumpAndSettle();
    expect(find.byType(app_ui.InputDialog), findsNothing);
    expect(find.text('8.8.8.8'), findsOneWidget);
    expect(queried, ['158.247.202.50', '8.8.8.8']);
    expect(tester.takeException(), isNull);
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
        overrides: [ipRiskProvider(home.ip).overrideWith((_) async => home)],
        child: const IpRiskSheet(ip: '1.2.3.4'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Premium Residential IP'), findsOneWidget);
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
        of: find.text('Source Scamalytics'),
        matching: find.byType(app_ui.ListFooter),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Source Scamalytics')).dx,
      greaterThan(tester.getTopLeft(find.byType(RiskScoreCard)).dx),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('IP details keeps hiding but has no recheck action', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        overrides: [
          ipRiskProvider(sampleRisk.ip).overrideWith((_) async => sampleRisk),
        ],
        child: const IpRiskSheet(ip: '158.247.202.50'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide IP'), findsOneWidget);
    expect(find.byTooltip('Check again'), findsNothing);
    expect(find.byGlyph(AppGlyphs.refresh), findsNothing);
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
      expect(find.text('数据中心'), findsOneWidget);
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
        final datacenterText = find.text('数据中心');
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
      final checkTopLeft = tester.getTopLeft(find.text('机房或代理'));
      final cardTopLeft = tester.getTopLeft(find.byType(RiskChecksCard));
      expect(checkTopLeft.dx, cardTopLeft.dx + 20);
      expect(checkTopLeft.dy, cardTopLeft.dy + 20);
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
    'failed risk card retries inline with loading and card transition',
    (tester) async {
      var attempts = 0;
      Completer<IpRisk>? retryCompleter;
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
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
      expect(
        find.widgetWithText(app_ui.FilledButton, l.retry),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(app_ui.FilledButton),
          matching: find.byGlyph(AppGlyphs.refresh),
        ),
        findsOneWidget,
      );

      final errorCardFinder = find.ancestor(
        of: find.text(l.ipRiskFailed),
        matching: find.byType(app_ui.Card),
      );
      final beforeCardRect = tester.getRect(errorCardFinder);

      retryCompleter = Completer<IpRisk>();
      await tester.tap(find.widgetWithText(app_ui.FilledButton, l.retry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('158.247.202.50'), findsOneWidget);
      expect(tester.getRect(errorCardFinder), beforeCardRect);
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
    'instant retry failure holds spinner briefly without flashing or bouncing card',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
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
      final errorCardFinder = find.ancestor(
        of: find.text(l.ipRiskFailed),
        matching: find.byType(app_ui.Card),
      );
      final beforeCardRect = tester.getRect(errorCardFinder);

      await tester.tap(find.widgetWithText(app_ui.FilledButton, l.retry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(attempts, 2);
      expect(tester.getRect(errorCardFinder), beforeCardRect);
      expect(find.byType(app_ui.ActivityIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(tester.getRect(errorCardFinder), beforeCardRect);
      expect(find.widgetWithText(app_ui.FilledButton, l.retry), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'location card stacks country and region cleanly with standalone ASN pill',
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
            ipRiskProvider(longRisk.ip).overrideWith((_) async => longRisk),
          ],
          child: const IpRiskSheet(ip: '58.247.1.2'),
        ),
      );
      await tester.pumpAndSettle();

      final sheetCtx = tester.element(find.byType(IpRiskSheet));
      final l = sheetCtx.appLocalizations;
      expect(find.text('Shanghai · Hongkou (Hongkou Qu)'), findsOneWidget);
      expect(find.text('AS4811'), findsOneWidget);
      expect(find.text(l.ipOrganization), findsOneWidget);
      expect(find.text(l.operatorOrAsn), findsNothing);
      expect(
        find.text('Shanghai Information Network Co., Ltd.'),
        findsOneWidget,
      );
      expect(find.textContaining('· AS4811'), findsNothing);
      final asnBox = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('AS4811'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (asnBox.decoration as ShapeDecoration).color,
        DashboardColors.of(sheetCtx).tone,
      );
      final countryFinder = find.byWidgetPredicate(
        (w) => w is app_ui.EmojiText && w.text == '🇨🇳 China',
      );
      expect(countryFinder, findsOneWidget);
      expect(find.byType(app_ui.Divider), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('Shanghai · Hongkou (Hongkou Qu)')).dy,
        greaterThan(tester.getTopLeft(countryFinder).dy),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
