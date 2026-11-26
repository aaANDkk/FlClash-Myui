import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('a mouse press dragged off a card it won at once fades', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      HostApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 64,
            child: Card(onPressed: () => taps++, child: const Text('card')),
          ),
        ),
      ),
    );
    double pressed() =>
        tester.widget<CardSurface>(find.byType(CardSurface)).pressed.value;

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('card')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(pressed(), 1);

    await gesture.moveBy(const Offset(0, kTouchSlop * 2));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(pressed(), 0);
    expect(taps, 0);
    await gesture.removePointer();
  });

  testWidgets('a card given a fill rests on it and still inks a press', (
    tester,
  ) async {
    const clear = Color(0x00000000);
    await tester.pumpWidget(
      HostApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 64,
            child: Card(
              fill: clear,
              onPressed: () {},
              child: const Text('card'),
            ),
          ),
        ),
      ),
    );
    CardSurface surface() =>
        tester.widget<CardSurface>(find.byType(CardSurface));
    expect(surface().fill, clear);
    expect(surface().inkColor.a, greaterThan(0));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('card')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(surface().pressed.value, 1);
    expect(surface().fill, clear);
    await gesture.up();
    await tester.pumpAndSettle();
    await gesture.removePointer();
  });
}
