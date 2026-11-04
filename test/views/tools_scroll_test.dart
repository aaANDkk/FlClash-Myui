import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

List<NavigationItem> _moreItems() => [
  for (var index = 0; index < 4; index++)
    NavigationItem(
      glyph: AppGlyphs.logs,
      label: PageLabel.logs,
      builder: (_) => const SizedBox.shrink(),
    ),
];

ScrollPosition _toolsPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ToolsView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final initial in [0.0, 0.001, 0.1, 1.0, 10.0, 120.0]) {
    testWidgets('first tools layout preserves offset $initial without jumping '
        'to the estimated bottom', (tester) async {
      _phone(tester);
      final controller = ScrollController(initialScrollOffset: initial);
      addTearDown(controller.dispose);
      final container = ProviderContainer(
        overrides: [
          moreToolsSelectorStateProvider.overrideWithValue(
            MoreToolsSelectorState(navigationItems: _moreItems()),
          ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = const Size(400, 400);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            child: PrimaryScrollController(
              controller: controller,
              child: const ToolsView(),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 20; frame++) {
        expect(_toolsPosition(tester).pixels, closeTo(initial, 0.01));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_toolsPosition(tester).maxScrollExtent, greaterThan(120));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('late tool entries do not move a restored near-top position', (
    tester,
  ) async {
    _phone(tester);
    final controller = ScrollController(initialScrollOffset: 1);
    addTearDown(controller.dispose);
    final container = ProviderContainer(
      overrides: [
        moreToolsSelectorStateProvider.overrideWithValue(
          const MoreToolsSelectorState(navigationItems: []),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(400, 400);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: PrimaryScrollController(
            controller: controller,
            child: const ToolsView(),
          ),
        ),
      ),
    );
    await tester.pump();
    final before = _toolsPosition(tester).pixels;
    container.updateOverrides([
      moreToolsSelectorStateProvider.overrideWithValue(
        MoreToolsSelectorState(navigationItems: _moreItems()),
      ),
    ]);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_toolsPosition(tester).pixels, closeTo(before, 0.01));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final animation in TabAnimation.values) {
    testWidgets('tools keeps a user scroll when returning through '
        '${animation.name} navigation', (tester) async {
      _phone(tester);
      final container = ProviderContainer(
        overrides: [
          navigationItemsStateProvider.overrideWithValue(
            NavigationItemsState(
              value: [
                NavigationItem(
                  glyph: AppGlyphs.dashboard,
                  label: PageLabel.dashboard,
                  builder: (_) => const Text('dashboard'),
                ),
                NavigationItem(
                  glyph: AppGlyphs.tools,
                  label: PageLabel.tools,
                  builder: (_) => const ToolsView(),
                ),
              ],
            ),
          ),
          moreToolsSelectorStateProvider.overrideWithValue(
            MoreToolsSelectorState(navigationItems: _moreItems()),
          ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = const Size(400, 400);
      container
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(tabAnimation: animation));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(includeNavigatorKey: false, child: HomePage()),
        ),
      );
      await tester.pumpAndSettle();
      container.read(currentPageLabelProvider.notifier).toPage(PageLabel.tools);
      await tester.pumpAndSettle();
      expect(_toolsPosition(tester).pixels, 0);
      await tester.drag(find.byKey(toolsStoreKey), const Offset(0, -180));
      await tester.pumpAndSettle();
      final before = _toolsPosition(tester).pixels;
      expect(before, greaterThan(0));
      container
          .read(currentPageLabelProvider.notifier)
          .toPage(PageLabel.dashboard);
      await tester.pumpAndSettle();
      container.read(currentPageLabelProvider.notifier).toPage(PageLabel.tools);
      await tester.pumpAndSettle();
      expect(_toolsPosition(tester).pixels, closeTo(before, 0.01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
