import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/service_probe.dart' show routedOutbound;
import 'package:fl_clash/features/ip_quality/ip_locate.dart';
import 'package:fl_clash/features/ip_quality/ip_lookup_view.dart';
import 'package:fl_clash/features/ip_quality/risk_model.dart';
import 'package:fl_clash/features/ip_quality/risk_provider.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart' as app_ui;
import 'package:fl_clash/ui/vertical_ticket_perforation.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';

const _outboundIp = '158.247.202.50';
const _customIp = '1.1.1.1';

const _outboundRisk = IpRisk(
  ip: _outboundIp,
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
    IpRiskCheck(group: IpRiskGroup.blacklist, name: 'Spamhaus', hit: false),
    IpRiskCheck(group: IpRiskGroup.proxy, name: 'Anonymizing VPN', hit: false),
    IpRiskCheck(group: IpRiskGroup.proxy, name: 'Server', hit: true),
  ],
);

const _customRisk = IpRisk(
  ip: _customIp,
  score: 0,
  level: IpRiskLevel.low,
  country: 'Australia',
  countryCode: 'AU',
  region: 'Queensland',
  city: 'Brisbane',
  organization: 'Cloudflare, Inc.',
  asn: 'AS13335',
  hostname: 'one.one.one.one',
  checks: [
    IpRiskCheck(group: IpRiskGroup.datacenter, name: 'Datacenter', hit: false),
    IpRiskCheck(
      group: IpRiskGroup.datacenter,
      name: 'Residential Proxy',
      hit: false,
    ),
    IpRiskCheck(group: IpRiskGroup.blacklist, name: 'Firehol', hit: false),
    IpRiskCheck(group: IpRiskGroup.proxy, name: 'Server', hit: false),
  ],
);

class _FakeOutboundProbe extends OutboundIpProbe {
  _FakeOutboundProbe(this._initial);

  final RoutedProbeState<String, IpInfo> _initial;
  int refreshes = 0;

  @override
  RoutedProbeState<String, IpInfo> build() => _initial;

  @override
  void watch(String target) {}

  @override
  void unwatch(String target) {}

  @override
  void refresh(Iterable<String> targets) {
    refreshes++;
  }
}

Widget _buildApp(
  Widget child, {
  _FakeOutboundProbe? probe,
  app_ui.ThemeMode themeMode = app_ui.ThemeMode.light,
  Locale locale = const Locale('en'),
}) {
  final effectiveProbe =
      probe ??
      _FakeOutboundProbe(
        const RoutedProbeState({
          routedOutbound: ProbeEntry(
            phase: ProbePhase.fresh,
            value: IpInfo(ip: _outboundIp, countryCode: 'KR'),
          ),
        }),
      );
  return TestApp(
    themeMode: themeMode,
    locale: locale,
    overrides: [
      outboundIpProbeProvider.overrideWith(() => effectiveProbe),
      ipRiskProvider.overrideWith((_, ip) async {
        if (ip == _customIp) return _customRisk;
        return _outboundRisk;
      }),
      ipLocateProvider.overrideWith((_, ip) async {
        if (ip == _customIp) {
          return const IpLocateInfo(
            ip: _customIp,
            company: 'Cloudflare, Inc.',
            network: 'CLOUDFLARENET',
            asn: 'AS13335',
          );
        }
        return const IpLocateInfo(
          ip: _outboundIp,
          company: 'The Constant Company, LLC',
          network: 'AS-CHOOPA',
          asn: 'AS20473',
        );
      }),
    ],
    child: child,
  );
}

void main() {
  testWidgets(
    'ToolsView orders DNS queries, IP Lookup, Traffic Statistics, Speed Test',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildApp(const ToolsView()));
      await tester.pumpAndSettle();

      final dns = find.text('DNS queries');
      final ipLookup = find.text('IP Lookup');
      final traffic = find.text('Traffic Statistics');
      final speed = find.text('Speed Test');

      expect(dns, findsOneWidget);
      expect(ipLookup, findsOneWidget);
      expect(traffic, findsOneWidget);
      expect(speed, findsOneWidget);

      expect(tester.getTopLeft(dns).dy, lessThan(tester.getTopLeft(ipLookup).dy));
      expect(
        tester.getTopLeft(ipLookup).dy,
        lessThan(tester.getTopLeft(traffic).dy),
      );
      expect(
        tester.getTopLeft(traffic).dy,
        lessThan(tester.getTopLeft(speed).dy),
      );

      await tester.tap(ipLookup);
      await tester.pumpAndSettle();
      expect(find.byType(IpLookupView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('IpLookupView searches custom IP, validates input, and resets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp(const IpLookupView()));
    await tester.pumpAndSettle();

    final l = tester.element(find.byType(IpLookupView)).appLocalizations;
    expect(find.text(l.outboundIpAddress), findsOneWidget);
    expect(find.text(_outboundIp), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('KR'), findsOneWidget);
    expect(find.textContaining('AS20473'), findsOneWidget);
    expect(find.textContaining('AS-CHOOPA'), findsOneWidget);
    expect(find.text(l.ipFlags), findsAtLeastNWidgets(1));
    expect(find.byGlyph(AppGlyphs.refresh), findsNothing);
    expect(find.byTooltip(l.hideIp), findsOneWidget);

    await tester.enterText(find.byType(app_ui.SearchField), '192.168.1.1');
    await tester.tap(find.text(l.search));
    await tester.pumpAndSettle();
    expect(find.text(l.ipRiskInvalid), findsOneWidget);
    expect(find.text(_outboundIp), findsOneWidget);

    await tester.enterText(find.byType(app_ui.SearchField), '$_customIp:443');
    await tester.tap(find.text(l.search));
    await tester.pumpAndSettle();
    expect(find.text(l.ipAddress), findsOneWidget);
    expect(find.text(l.outboundIpAddress), findsNothing);
    expect(find.text(_customIp), findsAtLeastNWidgets(1));
    expect(find.text('AU'), findsOneWidget);
    expect(find.textContaining('AS13335'), findsOneWidget);
    expect(find.text('Cloudflare, Inc.'), findsOneWidget);

    await tester.tap(find.text(l.outboundIp));
    await tester.pumpAndSettle();
    expect(find.text(_outboundIp), findsOneWidget);
    expect(find.textContaining('AS20473'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('IpLookupView renders sparse UK attribution cleanly', (
    tester,
  ) async {
    const ukIp = '141.98.252.152';
    const ukRisk = IpRisk(
      ip: ukIp,
      score: 100,
      level: IpRiskLevel.veryHigh,
      country: 'United Kingdom',
      countryCode: 'GB',
      region: 'England',
      city: 'Goodmayes',
      asn: 'AS39351',
      checks: [
        IpRiskCheck(group: IpRiskGroup.datacenter, name: 'Datacenter', hit: true),
        IpRiskCheck(group: IpRiskGroup.blacklist, name: 'Firehol', hit: false),
      ],
    );
    const ukLocate = IpLocateInfo(
      ip: ukIp,
      company: '31173 Services AB',
      network: '31173 Services AB',
      asn: 'AS39351',
    );

    for (final size in [const Size(1080, 760), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        TestApp(
          locale: const Locale('zh', 'CN'),
          overrides: [
            outboundIpProbeProvider.overrideWith(
              () => _FakeOutboundProbe(
                const RoutedProbeState({
                  routedOutbound: ProbeEntry(
                    phase: ProbePhase.fresh,
                    value: IpInfo(ip: ukIp, countryCode: 'GB'),
                  ),
                }),
              ),
            ),
            ipRiskProvider.overrideWith((_, _) async => ukRisk),
            ipLocateProvider.overrideWith((_, _) async => ukLocate),
          ],
          child: const IpLookupView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GB'), findsOneWidget);
      expect(find.text('31173 Services AB'), findsOneWidget);
      expect(find.text('AS39351'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  for (final scenario in [
    (size: const Size(360, 820), dark: false),
    (size: const Size(800, 760), dark: false),
    (size: const Size(1080, 760), dark: false),
    (size: const Size(1080, 760), dark: true),
  ]) {
    testWidgets('IpLookupView renders cleanly at $scenario', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildApp(
          const IpLookupView(),
          themeMode: scenario.dark
              ? app_ui.ThemeMode.dark
              : app_ui.ThemeMode.light,
          locale: const Locale('zh', 'CN'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('IP 查询'), findsOneWidget);
      expect(find.text('出站 IP 地址'), findsOneWidget);
      expect(find.text(_outboundIp), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect(find.text('数据中心'), findsWidgets);
      final scale = find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label?.endsWith('28 / 100') == true,
        ),
        matching: find.byType(CustomPaint),
      );
      final trackColor = DashboardColors.of(tester.element(scale)).tone2;
      expect(scale, paints..rsuperellipse(color: trackColor));
      final perforation = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is VerticalTicketPerforationPainter,
      );
      if (scenario.size.width >= 760) {
        expect(perforation, findsOneWidget);
        final bounds = tester.getRect(perforation);
        final card = tester.getRect(
          find.ancestor(of: perforation, matching: find.byType(app_ui.Card)),
        );
        expect(bounds.top, card.top);
        expect(bounds.bottom, card.bottom);
        Rect cardAround(Finder child) => tester.getRect(
          find.ancestor(of: child, matching: find.byType(app_ui.Card)),
        );
        final riskCard = cardAround(find.text('28'));
        final flagsCard = cardAround(find.byGlyph(AppGlyphs.target));
        expect(
          bounds.center.dx,
          closeTo((riskCard.right + flagsCard.left) / 2, 0.01),
        );

        final theme = app_ui.Theme.of(tester.element(perforation));
        final notchColor = app_ui.SurfaceLevel.page.colorOf(theme.colorScheme);
        expect(
          perforation,
          paints
            ..circle(x: bounds.width / 2, y: 0, radius: 9, color: notchColor)
            ..circle(
              x: bounds.width / 2,
              y: bounds.height,
              radius: 9,
              color: notchColor,
            ),
        );
      } else {
        expect(perforation, findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
