import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('a connected bar shares its width among labels, rounds only '
      'its ends and the chosen one, and answers a press on another', (
    tester,
  ) async {
    final changes = <int>[];
    await tester.pumpWidget(
      HostApp(
        home: HostScaffold(
          body: SizedBox(
            width: 303,
            child: ConnectedButtonBar<int>(
              segments: const [(0, 'One'), (1, 'Two'), (2, 'Three')],
              value: 0,
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttons = find.byType(ConnectedButton);
    expect(buttons, findsNWidgets(3));
    for (final index in [0, 1, 2]) {
      final rect = tester.getRect(buttons.at(index));
      expect(rect.height, viewSwitcherHeight);
      expect(rect.width, 99);
    }
    BorderRadius radiusOf(int index) {
      final decoration =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: buttons.at(index),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as ShapeDecoration;
      return (decoration.shape as RoundedSuperellipseBorder).borderRadius
          as BorderRadius;
    }

    expect(radiusOf(0), BorderRadius.circular(22));
    expect(radiusOf(1), BorderRadius.circular(10));
    expect(
      radiusOf(2),
      const BorderRadius.horizontal(
        left: Radius.circular(10),
        right: Radius.circular(22),
      ),
    );

    await tester.tap(find.text('One'));
    await tester.tap(find.text('Three'));
    expect(changes, [2]);
  });

  testWidgets('a screen reader activates a connected button as a press '
      'would', (tester) async {
    final semantics = tester.ensureSemantics();
    final changes = <int>[];
    await tester.pumpWidget(
      HostApp(
        home: HostScaffold(
          body: SizedBox(
            width: 303,
            child: ConnectedButtonBar<int>(
              segments: const [(0, 'One'), (1, 'Two'), (2, 'Three')],
              value: 0,
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.semantics.tap(find.semantics.byLabel('Three'));

    expect(changes, [2]);
    semantics.dispose();
  });
}
