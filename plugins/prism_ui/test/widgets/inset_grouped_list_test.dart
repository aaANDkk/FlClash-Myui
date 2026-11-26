import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

void main() {
  Future<void> pumpSection(
    WidgetTester tester,
    double width, {
    ListTextScale scale = ListTextScale.regular,
  }) async {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TestApp(
        child: HostScaffold(
          body: SizedBox(
            width: width,
            child: Builder(
              builder: (context) => Padding(
                padding: context.listInsets.page(),
                child: ListTextScope(
                  scale: scale,
                  child: generateSection(
                    title: 'header',
                    items: [
                      DecorationListItem(
                        title: const Text('one line'),
                        onPressed: () {},
                      ),
                      DecorationListItem(
                        title: const Text('two lines'),
                        subtitle: const Text('subtitle'),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder row(String title) => find.widgetWithText(DecorationListItem, title);

  for (final (width, margin, leading) in [
    (375.0, 16.0, 16.0),
    (402.0, 20.0, 16.0),
    (440.0, 20.0, 20.0),
  ]) {
    testWidgets(
      'a section ${width.toInt()} wide stands $margin in and sets its '
      'text $leading inside',
      (tester) async {
        await pumpSection(tester, width);

        final card = tester.getRect(row('one line'));
        expect(card.left, margin);
        expect(width - card.right, margin);
        expect(
          tester.getTopLeft(find.text('one line')).dx - card.left,
          leading,
        );
      },
    );
  }

  testWidgets('a row stands 53 as iOS 27 sets one line, and two lines stack '
      'their text 10 in from each edge', (tester) async {
    await pumpSection(tester, 402);

    expect(tester.getSize(row('one line')).height, 53);
    final twoLines = tester.getRect(row('two lines'));
    final title = tester.getRect(find.text('two lines'));
    final subtitle = tester.getRect(find.text('subtitle'));
    expect(title.top - twoLines.top, 10);
    expect(subtitle.top, title.bottom);
    expect(twoLines.bottom - subtitle.bottom, 10);
    expect(twoLines.height, 62);
  });

  testWidgets('a compact section sets each line a step smaller with the same '
      'paddings, so its rows stand 51 and 58', (tester) async {
    await pumpSection(tester, 402, scale: ListTextScale.compact);

    expect(tester.getSize(row('one line')).height, 51);
    expect(tester.getSize(row('two lines')).height, 58);
    expect(tester.getSize(find.text('header')).height, 20);
    expect(
      tester
          .widget<RichText>(
            find.descendant(
              of: find.text('header'),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style
          ?.fontWeight,
      FontWeight.w600,
    );
  });

  for (final textScale in [1.0, 1.3, 2.0]) {
    testWidgets('a row asked to stand 48 keeps the padding it has at the '
        'default text size at ${textScale}x', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        TestApp(
          child: HostScaffold(
            body: Column(
              children: [
                DecorationListItem(
                  title: const Text('short'),
                  minHeight: 48,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.getSize(row('short')).height -
            tester.getSize(find.text('short')).height,
        26,
      );
    });
  }

  testWidgets('a section rounds its ends with the list corner as a '
      'superellipse', (tester) async {
    await pumpSection(tester, 402);

    OutlinedBorder? shapeOf(String title) => tester
        .widget<Card>(
          find.descendant(of: row(title), matching: find.byType(Card)),
        )
        .shape;
    expect(AppCorner.listGroup, 26);
    expect(
      shapeOf('one line'),
      AppShape.of(
        AppRadius.vertical(top: AppCorner.listGroup, bottom: AppCorner.none),
      ),
    );
    expect(
      shapeOf('two lines'),
      AppShape.of(
        AppRadius.vertical(top: AppCorner.none, bottom: AppCorner.listGroup),
      ),
    );
    expect(shapeOf('one line'), isA<RoundedSuperellipseBorder>());
  });

  testWidgets('a footer hangs its last line into the gap of the section '
      'after it, and a last one, with no gap below, does not', (tester) async {
    late double hang;
    Widget section({required bool last}) => generateSection(
      items: [const DecorationListItem(title: Text('row'))],
      footer: last ? 'last' : 'before',
      last: last,
    );
    await tester.pumpWidget(
      TestApp(
        child: HostScaffold(
          body: Builder(
            builder: (context) {
              hang = (listSectionGap - 16.33) * 1.mAp(context);
              return ListView(
                children: [section(last: false), section(last: true)],
              );
            },
          ),
        ),
      ),
    );

    Rect footerOf(String text) => tester.getRect(
      find.ancestor(of: find.text(text), matching: find.byType(ListFooter)),
    );
    expect(
      footerOf('before').bottom,
      moreOrLessEquals(tester.getRect(find.text('before')).bottom - hang),
    );
    expect(footerOf('last').bottom, tester.getRect(find.text('last')).bottom);
  });

  testWidgets('a decorated row sets its sides at the top when asked', (
    tester,
  ) async {
    Widget row(ListRowAlignment alignment) => DecorationListItem(
      leading: SizedBox(key: ValueKey(alignment), width: 24, height: 10),
      title: const Text('title'),
      subtitle: const Text('one\ntwo\nthree'),
      alignment: alignment,
    );
    await tester.pumpWidget(
      TestApp(
        child: HostScaffold(
          body: Column(
            children: [row(ListRowAlignment.center), row(ListRowAlignment.top)],
          ),
        ),
      ),
    );

    double topIn(ListRowAlignment alignment) {
      final leading = find.byKey(ValueKey(alignment));
      return tester.getTopLeft(leading).dy -
          tester
              .getTopLeft(
                find.ancestor(
                  of: leading,
                  matching: find.byType(DecorationListItem),
                ),
              )
              .dy;
    }

    expect(
      topIn(ListRowAlignment.top),
      lessThan(topIn(ListRowAlignment.center)),
    );
  });
}
