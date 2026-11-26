import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

Future<SnapSheetRoute<void>> _openSheet(
  WidgetTester tester, {
  required bool glass,
  bool ownNavigator = false,
}) async {
  late BuildContext page;
  final body = Builder(
    builder: (context) {
      page = context;
      return const Text('page');
    },
  );
  await tester.pumpWidget(
    HostApp(
      builder: (_, child) => LiquidGlassScope(enabled: glass, child: child!),
      home: HostScaffold(
        body: ownNavigator
            ? Navigator(
                pages: [RootPage(child: body)],
                onDidRemovePage: (_) {},
              )
            : body,
      ),
    ),
  );
  final route = SnapSheetRoute<void>(
    builder: (_, _) => const Text('sheet'),
    sheetBarrierColor: const Color(0x42000000),
    barrierLabel: '',
  );
  unawaited(Navigator.of(page).push(route));
  return route;
}

bool _pageSnapshots(WidgetTester tester) => tester
    .widget<SnapshotWidget>(
      find
          .ancestor(
            of: find.text('page', skipOffstage: false),
            matching: find.byType(SnapshotWidget, skipOffstage: false),
          )
          .first,
    )
    .controller
    .allowSnapshotting;

void main() {
  for (final ownNavigator in [false, true]) {
    testWidgets('a page draws from a snapshot only while a sheet moves over it'
        '${ownNavigator ? ', in its own navigator' : ''}', (tester) async {
      final route = await _openSheet(
        tester,
        glass: false,
        ownNavigator: ownNavigator,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(route.animation!.isAnimating, isTrue);
      expect(_pageSnapshots(tester), isTrue);

      await tester.pumpAndSettle();
      expect(_pageSnapshots(tester), isFalse);

      unawaited(route.navigator!.maybePop());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_pageSnapshots(tester), isTrue);

      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
      expect(_pageSnapshots(tester), isFalse);
    });
  }

  testWidgets('a page under glass stays live while a sheet moves over it', (
    tester,
  ) async {
    final route = await _openSheet(tester, glass: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(route.animation!.isAnimating, isTrue);
    expect(_pageSnapshots(tester), isFalse);

    await tester.pumpAndSettle();
  });
}
