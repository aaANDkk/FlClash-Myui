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
      expect(find.text('t.me/aaANDkk1314'), findsOneWidget);
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

  testWidgets(
    'about page defers frosted card blur during route push and enables it on settle',
    (tester) async {
      final container = containerFor(tester, const Size(430, 840));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            locale: const Locale('en'),
            child: Builder(
              builder: (context) => FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (_, _, _) => const AboutView(),
                    ),
                  );
                },
                child: const Text('Open About'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open About'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final duringCards = tester
          .widgetList<MiuixFrostedCard>(find.byType(MiuixFrostedCard))
          .toList();
      expect(duringCards, isNotEmpty);
      expect(duringCards.every((c) => !c.blurEnabled), isTrue);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      final settledCards = tester
          .widgetList<MiuixFrostedCard>(find.byType(MiuixFrostedCard))
          .toList();
      expect(settledCards, isNotEmpty);
      expect(settledCards.every((c) => c.blurEnabled), isTrue);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'scrolling about page across bar alpha threshold keeps scroll position',
    (tester) async {
      final container = containerFor(tester, const Size(430, 560));
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

      final scrollView = find.byType(CustomScrollView);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: scrollView, matching: find.byType(Scrollable)),
      );
      expect(scrollable.position.pixels, 0);

      // Step through the progress == 0.35 bar-background alpha transition so
      // any Surface subtree remount would detach and reset ScrollPosition.
      final gesture = await tester.startGesture(const Offset(215, 420));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -35));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final midPixels = scrollable.position.pixels;
      expect(midPixels, greaterThan(120));
      await gesture.up();
      await tester.pumpAndSettle();

      final settledScrollable = tester.state<ScrollableState>(
        find.descendant(of: scrollView, matching: find.byType(Scrollable)),
      );
      expect(identical(settledScrollable, scrollable), isTrue);
      expect(settledScrollable.position.pixels, greaterThan(100));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
