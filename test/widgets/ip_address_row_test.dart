import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/connection/tracker_info_item.dart';
import 'package:fl_clash/features/ip_quality/ip_address_row.dart';
import 'package:fl_clash/features/ip_quality/ip_quality_sheet.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/ip_country.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

class _HiddenSettings extends AppSetting {
  @override
  AppSettingProps build() => const AppSettingProps(hideIp: true);
}

void main() {
  testWidgets('masking hides public endpoint port and colon', (tester) async {
    const boundaryKey = ValueKey('ip-mask-test');
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        overrides: [ipCountryProvider.overrideWith((ref, ip) async => 'US')],
        child: const Column(
          key: boundaryKey,
          children: [
            IpAddressRow(title: 'Target', address: '74.125.204.188:5228'),
            IpAddressRow(
              title: 'Source',
              address: '8.8.8.8:443',
              allowDetails: false,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('🇺🇸 74.125.204.188:5228'), findsOneWidget);
    expect(find.text('8.8.8.8:443'), findsOneWidget);

    ProviderScope.containerOf(tester.element(find.byKey(boundaryKey)))
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(hideIp: true));
    await tester.pumpAndSettle();
    expect(find.text('🇺🇸 *****'), findsOneWidget);
    expect(find.text('*****'), findsOneWidget);
    expect(find.textContaining('5228'), findsNothing);
    expect(find.textContaining('443'), findsNothing);
    expect(find.textContaining(':'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'DNS masks public addresses while local and synthetic addresses stay visible',
    (tester) async {
      await tester.pumpWidget(
        TestApp(
          wrapInProviderScope: true,
          overrides: [
            appSettingProvider.overrideWith(_HiddenSettings.new),
            ipCountryProvider.overrideWith((ref, ip) async => 'US'),
          ],
          child: const Column(
            children: [
              IpAddressRow(address: '2606:4700:4700::1111'),
              IpAddressRow(address: '198.18.0.1'),
              IpAddressRow(address: '192.168.1.1:53'),
              IpAddressRow(address: '[fd00::1]:53'),
              IpAddressRow(address: '127.0.0.1'),
              IpAddressRow(address: '10.0.0.1'),
              IpAddressRow(address: 'edge.example.com'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('🇺🇸 *****'), findsOneWidget);
      expect(find.text('*****'), findsNothing);
      for (final address in [
        '198.18.0.1',
        '192.168.1.1:53',
        '[fd00::1]:53',
        '127.0.0.1',
        '10.0.0.1',
        'edge.example.com',
      ]) {
        expect(find.text(address), findsOneWidget);
      }
      expect(find.textContaining('2606:'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a public source address follows hiding without opening details',
    (tester) async {
      await tester.pumpWidget(
        TestApp(
          wrapInProviderScope: true,
          overrides: [appSettingProvider.overrideWith(_HiddenSettings.new)],
          child: const IpAddressRow(
            title: 'Source',
            address: '8.8.8.8:443',
            allowDetails: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('*****'), findsOneWidget);
      expect(find.text('8.8.8.8:443'), findsNothing);
      expect(find.text('*****:443'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a public endpoint keeps its flag, masks port and colon, opens details in '
    'the same sheet and shares the global hide setting',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queried = <String>[];
      await tester.pumpWidget(
        TestApp(
          wrapInProviderScope: true,
          overrides: [
            appSettingProvider.overrideWith(_HiddenSettings.new),
            ipCountryProvider.overrideWith((ref, ip) async => 'US'),
            ipQualityProvider.overrideWith((ref, ip) async {
              queried.add(ip);
              return IpQuality(
                ip: ip,
                source: IpQualitySource.ipQuery,
                type: IpType.hosting,
              );
            }),
          ],
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTrackerInfoDetail(
                context,
                TrackerInfo(
                  id: 'test',
                  start: DateTime.utc(2026),
                  chains: const [],
                  rule: '',
                  rulePayload: '',
                  metadata: const Metadata(
                    sourceIP: '198.18.0.1',
                    sourcePort: '38120',
                    destinationIP: '74.125.204.188',
                    destinationPort: '5228',
                  ),
                ),
                'Connection details',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      ProviderScope.containerOf(
        tester.element(find.text('Open')),
      ).read(viewSizeProvider.notifier).value = const Size(
        400,
        1200,
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.dragFrom(
        tester.getCenter(find.byType(SheetDragHandle)),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(find.text('🇺🇸 *****'), findsOneWidget);
      expect(find.text('*****:38120'), findsNothing);
      expect(find.text('198.18.0.1:38120'), findsOneWidget);
      expect(queried, isEmpty);
      await tester.ensureVisible(find.text('🇺🇸 *****'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🇺🇸 *****'));
      await tester.pumpAndSettle();
      expect(find.text('IP Details'), findsOneWidget);
      expect(find.text('*****'), findsOneWidget);
      expect(find.text('74.125.204.188'), findsNothing);
      expect(queried, ['74.125.204.188']);
      await tester.scrollUntilVisible(
        find.text('Hide IP'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(Switch)),
        ).read(appSettingProvider).hideIp,
        isFalse,
      );
      expect(find.text('74.125.204.188'), findsOneWidget);
      final context = tester.element(find.text('IP Details'));
      expect(ModalRoute.of(context), isA<PagedSheetRoute>());
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(find.text('Connection details'), findsOneWidget);
      expect(find.text('🇺🇸 74.125.204.188:5228'), findsOneWidget);
      expect(find.text('198.18.0.1:38120'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('an unlabeled DNS answer opens IPv6 details, while a fake '
      'address retains copying', (tester) async {
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
        wrapInProviderScope: true,
        overrides: [
          ipCountryProvider.overrideWith((ref, ip) async => 'AU'),
          ipQualityProvider.overrideWith(
            (ref, ip) async => IpQuality(
              ip: ip,
              source: IpQualitySource.ipQuery,
              type: IpType.hosting,
            ),
          ),
        ],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IpAddressRow(address: '2606:4700:4700::1111'),
            IpAddressRow(address: '198.18.0.1'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('198.18.0.1'));
    await tester.pumpAndSettle();
    expect(copied, '198.18.0.1');
    await tester.tap(find.text('🇦🇺 2606:4700:4700::1111'));
    await tester.pumpAndSettle();
    expect(find.text('IP Details'), findsOneWidget);
    expect(find.text('2606:4700:4700::1111'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Hide IP'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Hide IP'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the outbound entry keeps its title and global hide setting', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        overrides: [
          appSettingProvider.overrideWith(_HiddenSettings.new),
          ipQualityProvider.overrideWith(
            (ref, ip) async => IpQuality(
              ip: ip,
              source: IpQualitySource.ipQuery,
              type: IpType.hosting,
            ),
          ),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showIpQualitySheet(context, ip: '1.1.1.1'),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Outbound IP'), findsOneWidget);
    expect(find.text('*****'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Hide IP'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Hide IP'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
