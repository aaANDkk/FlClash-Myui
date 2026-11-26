import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('a sized segmented control stands as tall as a button of its '
      'size, each segment as wide as its own label', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var value = 0;
    Widget build(TonalButtonSize? size) => TestApp(
      child: Center(
        child: StatefulBuilder(
          builder: (context, setState) => SegmentedControl<int>(
            size: size,
            segments: const [(0, 'All'), (1, 'Active 12'), (2, 'Failed')],
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );

    await tester.pumpWidget(build(TonalButtonSize.compact));
    final control = tester.getRect(find.byType(SegmentedControl<int>));
    expect(control.height, TonalButtonSize.compact.button);
    expect(control.width, lessThan(800));
    final presses = find.descendant(
      of: find.byType(SegmentedControl<int>),
      matching: find.byType(PressSurface),
    );
    for (final (index, label) in ['All', 'Active 12', 'Failed'].indexed) {
      expect(
        tester.getSize(presses.at(index)).width,
        tester.getSize(find.text(label)).width.ceil() + 20,
      );
    }
    expect(
      control.width,
      [
            for (final index in [0, 1, 2])
              tester.getSize(presses.at(index)).width,
          ].reduce((a, b) => a + b) +
          4,
    );

    await tester.tap(find.text('Failed'));
    await tester.pumpAndSettle();
    expect(value, 2);

    await tester.pumpWidget(build(TonalButtonSize.section));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(SegmentedControl<int>)).height,
      TonalButtonSize.section.button,
    );
    for (final (index, label) in ['All', 'Active 12', 'Failed'].indexed) {
      expect(
        tester.getSize(presses.at(index)).width,
        tester.getSize(find.text(label)).width.ceil() + 28,
      );
    }

    await tester.pumpWidget(build(null));
    expect(tester.getRect(find.byType(SegmentedControl<int>)).width, 800);
  });

  testWidgets('a sized control given less than its labels take shares '
      'the shortfall among its segments and keeps its thumb on the chosen '
      'one', (tester) async {
    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const labels = ['All', 'Active 12', 'Failed'];
    Widget build(
      double? width, {
      TextDirection direction = TextDirection.ltr,
    }) => TestApp(
      child: Directionality(
        textDirection: direction,
        child: Center(
          child: SizedBox(
            width: width,
            child: SegmentedControl<int>(
              size: TonalButtonSize.compact,
              segments: [
                for (final (index, label) in labels.indexed) (index, label),
              ],
              value: 1,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    final control = find.byType(SegmentedControl<int>);
    final presses = find.descendant(
      of: control,
      matching: find.byType(PressSurface),
    );
    List<double> widths() => [
      for (final index in [0, 1, 2]) tester.getSize(presses.at(index)).width,
    ];

    await tester.pumpWidget(build(null));
    final natural = widths();
    final total = natural.reduce((a, b) => a + b);
    await tester.pumpWidget(build(total / 2 + 4));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final (index, width) in widths().indexed) {
      expect(width, moreOrLessEquals(natural[index] / 2));
    }
    final primary = tester.element(control).colorScheme.primary;
    final thumb = find.descendant(
      of: control,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is ShapeDecoration &&
            (widget.decoration as ShapeDecoration).color == primary,
      ),
    );
    void expectThumbOnChosen() {
      final chosen = tester.getRect(presses.at(1));
      final thumbRect = tester.getRect(thumb);
      expect(thumbRect.left, moreOrLessEquals(chosen.left));
      expect(thumbRect.right, moreOrLessEquals(chosen.right));
    }

    expectThumbOnChosen();

    await tester.pumpWidget(build(total / 2 + 4, direction: TextDirection.rtl));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(presses.at(0)).left,
      greaterThan(tester.getRect(presses.at(2)).left),
    );
    expectThumbOnChosen();
  });

  testWidgets('with reduced motion the thumb and labels change at once', (
    tester,
  ) async {
    Widget build(int value) => TestApp(
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Center(
          child: SegmentedControl<int>(
            size: TonalButtonSize.compact,
            segments: const [(0, 'All'), (1, 'Active 12'), (2, 'Failed')],
            value: value,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final control = find.byType(SegmentedControl<int>);

    await tester.pumpWidget(build(0));
    await tester.pumpWidget(build(2));

    final colorScheme = tester.element(control).colorScheme;
    final thumb = find.descendant(
      of: control,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is ShapeDecoration &&
            (widget.decoration as ShapeDecoration).color == colorScheme.primary,
      ),
    );
    final chosen = find
        .descendant(of: control, matching: find.byType(PressSurface))
        .at(2);
    expect(tester.getRect(thumb), tester.getRect(chosen));
    expect(
      DefaultTextStyle.of(tester.element(find.text('Failed'))).style.color,
      colorScheme.onPrimary,
    );
  });

  test('only a sized control stretches', () {
    expect(
      () => SegmentedControl<int>(
        segments: const [(0, 'A')],
        value: 0,
        onChanged: (_) {},
        stretches: true,
      ),
      throwsAssertionError,
    );
  });

  testWidgets('a stretched sized control shares the width it is given '
      'equally at its size\'s height', (tester) async {
    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TestApp(
        child: Center(
          child: SizedBox(
            width: 304,
            child: SegmentedControl<int>(
              size: TonalButtonSize.section,
              stretches: true,
              segments: const [(0, 'A'), (1, 'Longer'), (2, 'B'), (3, 'C')],
              value: 1,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final control = find.byType(SegmentedControl<int>);
    expect(tester.getSize(control), const Size(304, 36));
    final presses = find.descendant(
      of: control,
      matching: find.byType(PressSurface),
    );
    for (final index in [0, 1, 2, 3]) {
      expect(tester.getSize(presses.at(index)).width, 75);
    }
  });
}
