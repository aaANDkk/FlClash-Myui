import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import '../helpers/host_scaffold.dart';

const _testUrl = 'https://example.com/generate_204';

class _RecordingProxiesAction extends ProxiesAction {
  static final List<String> tested = [];

  @override
  Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
    tested.add(proxy.name);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    _RecordingProxiesAction.tested.clear();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        proxiesActionProvider.overrideWith(_RecordingProxiesAction.new),
        delayDataSourceProvider.overrideWithBuild(
          (_, _) => {
            _testUrl: {'proxy 0': 123, 'proxy 1': 456},
          },
        ),
      ],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(900, 600);
  });

  tearDown(() => container.dispose());

  Future<void> pumpCards(WidgetTester tester, ProxyCardType type) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          homeBuilder: (child) => HostScaffold(body: child),
          child: Column(
            children: [
              for (var index = 0; index < 2; index++)
                SizedBox(
                  height: 120,
                  child: ProxyCard(
                    key: ValueKey('proxy $index'),
                    groupName: 'group',
                    testUrl: _testUrl,
                    proxy: Proxy(name: 'proxy $index', type: 'Shadowsocks'),
                    groupType: GroupType.Selector,
                    type: type,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> focusCard(WidgetTester tester, int index) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context?.findAncestorWidgetOfExactType<ProxyCard>()?.key ==
          ValueKey('proxy $index')) {
        return;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    fail('proxy card $index was not reachable by tab');
  }

  for (final type in ProxyCardType.values) {
    testWidgets('arrow right from a ${type.name} proxy card focuses its '
        'delay control', (tester) async {
      await pumpCards(tester, type);

      for (var index = 0; index < 2; index++) {
        await focusCard(tester, index);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        final focusNode = FocusManager.instance.primaryFocus;
        expect(focusNode, isA<SkipTraversalFocusNode>());
        expect(
          find.descendant(
            of: find.byWidget(focusNode!.context!.widget),
            matching: find.text(index == 0 ? '123 ms' : '456 ms'),
          ),
          findsOneWidget,
        );
      }
    });
  }

  testWidgets('tab walks card to card without stopping on the delay control', (
    tester,
  ) async {
    await pumpCards(tester, ProxyCardType.standard);

    await focusCard(tester, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final context = FocusManager.instance.primaryFocus?.context;
    expect(
      context?.findAncestorWidgetOfExactType<ProxyCard>()?.key,
      const ValueKey('proxy 1'),
    );
  });

  for (final brightness in Brightness.values) {
    for (final fallback in [false, true]) {
      for (final type in ProxyCardType.values) {
        testWidgets('selected colors stay coherent in ${brightness.name} '
            '${type.name}, fallback=$fallback', (tester) async {
          final result = switch (type) {
            ProxyCardType.loose => 123,
            ProxyCardType.standard => 900,
            ProxyCardType.compact => -1,
          };
          final scoped = ProviderContainer(
            overrides: [
              profilesProvider.overrideWith(TestProfiles.new),
              proxyNameProvider('group').overrideWithValue('proxy 0'),
              selectedProxyNameProvider(
                'group',
              ).overrideWithValue(fallback ? 'proxy 1' : 'proxy 0'),
              delayDataSourceProvider.overrideWithBuild(
                (_, _) => {
                  _testUrl: {'proxy 0': result, 'proxy 1': result},
                },
              ),
            ],
          );
          addTearDown(scoped.dispose);
          globalState.container = scoped;
          scoped.read(viewSizeProvider.notifier).value = const Size(900, 600);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: scoped,
              child: TestApp(
                theme: ThemeData(brightness: brightness),
                themeMode: ThemeMode.light,
                homeBuilder: (child) => HostScaffold(body: child),
                child: Column(
                  children: [
                    for (var index = 0; index < 2; index++)
                      SizedBox(
                        height: 120,
                        child: ProxyCard(
                          key: ValueKey('color $index'),
                          groupName: 'group',
                          testUrl: _testUrl,
                          proxy: Proxy(
                            name: 'proxy $index',
                            type: 'Shadowsocks',
                          ),
                          groupType: GroupType.URLTest,
                          type: type,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (var index = 0; index < 2; index++) {
            final root = find.byKey(ValueKey('color $index')).first;
            final scheme = tester.element(root).colorScheme;
            final selected = index == (fallback ? 1 : 0);
            final card = tester.widget<Card>(
              find.descendant(of: root, matching: find.byType(Card)),
            );
            expect(card.isSelected, selected);
            expect(card.fillsSelection, isFalse);
            expect(
              find.descendant(
                of: root,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is GlyphIcon && widget.glyph == Glyphs.check,
                ),
              ),
              findsNothing,
            );
            expect(
              card.side,
              selected
                  ? BorderSide(color: scheme.primary, width: 1.5)
                  : BorderSide.none,
            );
            final surface = tester.widget<PressSurface>(
              find
                  .descendant(of: root, matching: find.byType(PressSurface))
                  .first,
            );
            expect(surface.side, card.side);
            expect(card.radius, AppCorner.lg);
            if (selected) expect(surface.fill, scheme.primary.opacity15);
            final name = tester.widget<Text>(
              find.descendant(of: root, matching: find.text('proxy $index')),
            );
            expect(name.style!.color, scheme.onSurface);
            final desc = tester.widget<Text>(
              find.descendant(of: root, matching: find.text('Shadowsocks')),
            );
            expect(desc.style!.color, scheme.onSurface.opacity80);
            final latency = tester.widget<Text>(
              find.descendant(
                of: root,
                matching: find.text(
                  result > 0
                      ? '$result ms'
                      : delayFailureText(
                          result,
                          tester.element(root).appLocalizations,
                        ),
                ),
              ),
            );
            expect(latency.style!.color, scheme.delayColor(result));
            final badgeFinder = find.descendant(
              of: root,
              matching: find.byType(SelectionBadge),
            );
            if (index == 0) {
              final badge = tester.widget<SelectionBadge>(badgeFinder);
              expect(badge.glyph, Glyphs.pin);
              expect(tester.getSize(badgeFinder), const Size.square(22));
              final decoration =
                  tester
                          .widget<DecoratedBox>(
                            find.descendant(
                              of: badgeFinder,
                              matching: find.byType(DecoratedBox),
                            ),
                          )
                          .decoration
                      as ShapeDecoration;
              expect(decoration.shape, AppShape.circle);
              expect(
                decoration.color,
                selected
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: 0.14),
              );
              final glyph = tester.widget<GlyphIcon>(
                find.descendant(
                  of: badgeFinder,
                  matching: find.byType(GlyphIcon),
                ),
              );
              expect(glyph.color, selected ? scheme.onPrimary : scheme.primary);
            } else {
              expect(badgeFinder, findsNothing);
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets('enter on the delay control runs the delay test', (tester) async {
    await pumpCards(tester, ProxyCardType.standard);

    await focusCard(tester, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isA<SkipTraversalFocusNode>());

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(_RecordingProxiesAction.tested, ['proxy 0']);
  });
}
