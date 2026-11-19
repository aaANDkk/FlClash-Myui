import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_clash/features/ip_quality/ip_locate.dart';
import 'package:fl_clash/features/ip_quality/ip_quality_sheet.dart';
import 'package:fl_clash/features/ip_quality/risk_model.dart';
import 'package:fl_clash/features/ip_quality/risk_parser.dart';
import 'package:fl_clash/features/ip_quality/risk_provider.dart';
import 'package:fl_clash/features/ip_quality/risk_view.dart';
import 'package:fl_clash/ui/ui.dart' as app_ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

IpRisk scamalytics(String ip, {String? company, String? isp}) =>
    parseScamalytics(ip, '''Fraud Score: 10
      <th class="title">IP Address Information</th>
      ${company == null ? '' : '<th>Organization Name</th><td>$company</td>'}
      ${isp == null ? '' : '<th>ISP Name</th><td>$isp</td>'}
      <th>ASN</th><td>123</td>''')!;

void main() {
  for (final sample in [
    (
      ip: '36.231.152.8',
      company: 'Chunghwa Telecom Data Communication Business Group',
      network: 'Chunghwa Telecom Co., Ltd.',
      asn: 'AS3462',
    ),
    (
      ip: '103.151.173.91',
      company: 'KIDC LIMITED',
      network: 'IKUUU NETWORK LTD',
      asn: 'AS134972',
    ),
    (
      ip: '119.29.29.29',
      company: '16 COLLYER QUAY, # 18-29, INCOME AT RAFFLES, SINGAPORE',
      network: 'Shenzhen Tencent Computer Systems Company Limited',
      asn: 'AS132203',
    ),
  ]) {
    testWidgets(
      'IPLocate alone supplies company, ASN and number for ${sample.ip}',
      (tester) async {
        final base = scamalytics(
          sample.ip,
          company: 'n/a',
          isp: 'Scamalytics ISP',
        );
        await tester.pumpWidget(
          TestApp(
            locale: const Locale('en'),
            overrides: [
              ipRiskProvider(sample.ip).overrideWith((_) async => base),
              ipLocateProvider(sample.ip).overrideWith(
                (_) async => IpLocateInfo(
                  ip: sample.ip,
                  company: sample.company,
                  network: sample.network,
                  asn: sample.asn,
                ),
              ),
            ],
            child: IpRiskSheet(ip: sample.ip),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(sample.company), findsOneWidget);
        expect(find.text(sample.network), findsOneWidget);
        expect(find.text(sample.asn), findsOneWidget);
        expect(find.text('ASN'), findsOneWidget);
        expect(find.text('Scamalytics ISP'), findsNothing);
        expect(find.text('AS123'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('IPLocate failure shows retry and reuses successful risk data', (
    tester,
  ) async {
    final base = scamalytics(
      '1.2.3.4',
      company: 'Old Company',
      isp: 'Old Network',
    );
    var riskQueries = 0;
    var locateQueries = 0;
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        overrides: [
          ipRiskProvider('1.2.3.4').overrideWith((_) async {
            riskQueries++;
            return base;
          }),
          ipLocateProvider('1.2.3.4').overrideWith((_) async {
            if (++locateQueries == 1) return null;
            return const IpLocateInfo(ip: '1.2.3.4', company: 'New Company');
          }),
        ],
        child: const IpRiskSheet(ip: '1.2.3.4'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RiskScoreCard), findsNothing);
    await tester.tap(find.byType(app_ui.FilledButton));
    await tester.pumpAndSettle();
    expect(riskQueries, 1);
    expect(locateQueries, 2);
    expect(find.byType(RiskScoreCard), findsOneWidget);
    expect(find.text('New Company'), findsOneWidget);
    expect(find.text('Old Company'), findsNothing);
    expect(find.text('Old Network'), findsNothing);
    expect(find.text('AS123'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'IPLocate query parses the actual fields and rejects a different IP',
    () async {
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      var responseIp = '1.2.3.4';
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(
              options.uri.toString(),
              'https://iplocate.io/api/lookup/1.2.3.4',
            );
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'ip': responseIp,
                  'company': {'name': ' Company '},
                  'asn': {'name': 'Network', 'asn': 'AS123'},
                },
              ),
            );
          },
        ),
      );
      final result = await fetchIpLocate(dio, '1.2.3.4', CancelToken());
      expect(result.company, 'Company');
      expect(result.network, 'Network');
      responseIp = '8.8.8.8';
      await expectLater(
        fetchIpLocate(dio, '1.2.3.4', CancelToken()),
        throwsFormatException,
      );
    },
  );

  test(
    'IPLocate result survives repository reopening without another query',
    () async {
      Map<String, dynamic>? disk;
      var queries = 0;
      IpLocateRepository repository() => IpLocateRepository(
        read: (_) async => disk,
        write: (_, value) async {
          disk = value;
        },
        fetch: (ip, _) async {
          queries++;
          return IpLocateInfo(ip: ip, company: 'Company');
        },
      );
      expect(
        (await repository().load('1.2.3.4', CancelToken()))!.company,
        'Company',
      );
      expect(
        (await repository().load('1.2.3.4', CancelToken()))!.company,
        'Company',
      );
      expect(queries, 1);
    },
  );

  test(
    'IPLocate data is available while the cache write is still pending',
    () async {
      final saved = Completer<void>();
      const info = IpLocateInfo(ip: '1.2.3.4', company: 'Example');
      final repository = IpLocateRepository(
        read: (_) async => null,
        write: (_, _) => saved.future,
        fetch: (_, _) async => info,
      );
      try {
        expect(
          await repository
              .load(info.ip, CancelToken())
              .timeout(const Duration(seconds: 1)),
          info,
        );
        expect(saved.isCompleted, isFalse);
      } finally {
        saved.complete();
      }
    },
  );

  test('IPLocate failures are not cached', () async {
    var writes = 0;
    var attempts = 0;
    final repository = IpLocateRepository(
      read: (_) async => null,
      write: (_, _) async {
        writes++;
      },
      fetch: (_, _) async {
        attempts++;
        throw StateError('offline');
      },
    );
    expect(await repository.load('1.2.3.4', CancelToken()), isNull);
    expect(writes, 0);
    expect(attempts, 3);
  });

  test('disposing an IPLocate lookup stops automatic retries', () async {
    var attempts = 0;
    final cancel = CancelToken();
    final repository = IpLocateRepository(
      read: (_) async => null,
      write: (_, _) async => fail('Cancelled results must not be cached'),
      fetch: (_, token) async {
        attempts++;
        token.cancel();
        throw token.cancelError!;
      },
    );
    expect(await repository.load('1.2.3.4', cancel), isNull);
    expect(attempts, 1);
  });

  testWidgets('detail waits for IPLocate and shows both sources together', (
    tester,
  ) async {
    final locate = Completer<IpLocateInfo?>();
    final base = scamalytics(
      '1.2.3.4',
      company: 'Original Company',
      isp: 'Original Network',
    );
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        overrides: [
          ipRiskProvider('1.2.3.4').overrideWith((_) async => base),
          ipLocateProvider('1.2.3.4').overrideWith((_) => locate.future),
        ],
        child: const IpRiskSheet(ip: '1.2.3.4'),
      ),
    );
    await tester.pump();
    expect(find.byType(RiskScoreCard), findsNothing);
    expect(find.byType(app_ui.ActivityIndicator), findsOneWidget);
    expect(find.text('Original Company'), findsNothing);
    expect(find.text('AS123'), findsNothing);
    locate.complete(
      const IpLocateInfo(
        ip: '1.2.3.4',
        company: 'Preferred Company',
        network: 'Preferred Network',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Preferred Company'), findsOneWidget);
    expect(find.text('Preferred Network'), findsOneWidget);
    expect(find.text('Original Company'), findsNothing);
    expect(find.byType(RiskScoreCard), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
