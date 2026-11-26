import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';

void main() {
  Future<void> pumpRegion(
    WidgetTester tester,
    List<PopupMenuItem> Function(BuildContext context) menuBuilder,
  ) async {
    await tester.pumpWidget(
      TestApp(
        child: Center(
          child: ContextMenuRegion(
            menuBuilder: menuBuilder,
            child: const SizedBox(width: 200, height: 40, child: Text('row')),
          ),
        ),
      ),
    );
  }

  Future<void> rightClick(WidgetTester tester) async {
    await tester.tap(
      find.text('row'),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a menu builder runs only as its menu opens', (tester) async {
    var built = 0;
    await pumpRegion(tester, (_) {
      built++;
      return [PopupMenuItem(label: 'Copy', onPressed: () {})];
    });
    await tester.pumpAndSettle();
    expect(built, 0);

    await rightClick(tester);
    expect(built, 1);
    expect(find.byType(PopupMenu), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('a menu builder with nothing to offer opens no menu', (
    tester,
  ) async {
    await pumpRegion(tester, (_) => const []);

    await rightClick(tester);
    expect(find.byType(PopupMenu), findsNothing);
  });
}
