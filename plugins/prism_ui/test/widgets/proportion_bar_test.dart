import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/proportion_bar.dart';

import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

void main() {
  const first = Color(0xFF0000FF);
  const second = Color(0xFF00FF00);

  Future<void> pumpSegments(
    WidgetTester tester,
    List<({int value, Color color})> segments,
  ) async {
    await tester.pumpWidget(
      HostApp(
        home: HostScaffold(
          body: Center(
            child: SizedBox(
              width: 202,
              child: ProportionBar(segments: segments),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpBar(WidgetTester tester, int a, int b) => pumpSegments(
    tester,
    [(value: a, color: first), (value: b, color: second)],
  );

  double widthOf(WidgetTester tester, Color color) => tester
      .getSize(
        find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == color,
        ),
      )
      .width;

  testWidgets('sizes each segment to its share, a gap between them', (
    tester,
  ) async {
    await pumpBar(tester, 300, 100);

    expect(widthOf(tester, first), moreOrLessEquals(150, epsilon: 1));
    expect(widthOf(tester, second), moreOrLessEquals(50, epsilon: 1));
  });

  testWidgets('shows the track alone while the parts come to nothing', (
    tester,
  ) async {
    await pumpBar(tester, 0, 0);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            (widget.color == first || widget.color == second),
      ),
      findsNothing,
    );
    expect(find.byType(ColoredBox), findsWidgets);
  });

  testWidgets('a part too small to show leaves no gap for itself', (
    tester,
  ) async {
    await pumpBar(tester, 1000, 1);

    expect(widthOf(tester, first), 202);
  });

  testWidgets('shows the track while every part is too small to show', (
    tester,
  ) async {
    await pumpSegments(tester, [
      for (var index = 0; index < 300; index++) (value: 1, color: first),
    ]);

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == first,
      ),
      findsNothing,
    );
  });
}
