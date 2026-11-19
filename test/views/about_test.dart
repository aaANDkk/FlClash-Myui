import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/features/about/miuix_bg_effect.dart';
import 'package:fl_clash/features/about/miuix_frosted_card.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/about.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

void main() {
  setUpAll(() {
    globalState.packageInfo = PackageInfo(
      appName: appName,
      packageName: 'com.follow.clash',
      version: '0.9.3',
      buildNumber: '1',
    );
  });

  ProviderContainer containerFor(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.listen(appSettingProvider, (_, _) {}, fireImmediately: true);
    container.read(viewSizeProvider.notifier).update((_) => size);
    return container;
  }

  testWidgets(
    'miuix about page renders flowing backdrop, chromatic title, frosted cards, and scroll collapse',
    (tester) async {
      final container = containerFor(tester, const Size(430, 560));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('en'),
            child: AboutView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(MiuixAboutBackdrop), findsOneWidget);
      expect(find.byType(MiuixChromaticLogo), findsOneWidget);
      expect(find.byType(MiuixChromaticTitle), findsOneWidget);
      expect(find.text(appName), findsOneWidget);
      expect(find.text('v0.9.3'), findsOneWidget);
      expect(find.text('GPL-3.0'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);

      final titlePadding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.text(appName),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(
        titlePadding.padding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
      final title = tester.widget<Text>(find.text(appName));
      expect(title.overflow, TextOverflow.visible);
      expect(title.softWrap, isFalse);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(MiuixFrostedSection), findsNWidgets(2));
      expect(find.byType(DecorationListItem), findsNWidgets(6));
      expect(find.text('Telegram'), findsOneWidget);
      expect(find.text('aaANDkk'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('about hero app icon 5-tap enables developer mode', (tester) async {
    final container = containerFor(tester, const Size(900, 700));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          locale: Locale('en'),
          child: AboutView(dynamicBackground: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(appSettingProvider).developerMode, isFalse);
    final icon = find.byType(MiuixChromaticLogo);
    for (var i = 0; i < 5; i++) {
      await tester.tap(icon);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(container.read(appSettingProvider).developerMode, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
