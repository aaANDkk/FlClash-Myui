import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('a chip that opens a menu carries a chevron, unless it deletes', (
    tester,
  ) async {
    Future<void> pump(Chip chip) =>
        tester.pumpWidget(TestApp(child: Center(child: chip)));

    await pump(Chip(label: 'App', onPressed: () {}, opensMenu: true));
    expect(find.byGlyph(Glyphs.chevronDown), findsOneWidget);

    await pump(Chip(label: 'App', onPressed: () {}));
    expect(find.byGlyph(Glyphs.chevronDown), findsNothing);

    await pump(Chip(label: 'host:x', onDeleted: () {}, opensMenu: true));
    expect(find.byGlyph(Glyphs.chevronDown), findsNothing);
    expect(find.byGlyph(Glyphs.close), findsOneWidget);
  });

  testWidgets('a chip stands as tall as a section button', (tester) async {
    await tester.pumpWidget(
      TestApp(
        child: Center(
          child: Chip(label: 'App', onPressed: () {}),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(Chip)).height,
      TonalButtonSize.section.button,
    );
  });
}
