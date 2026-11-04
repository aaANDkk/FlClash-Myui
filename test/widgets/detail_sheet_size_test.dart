import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('detail sheets keep their expanded frame through shorter pages '
      'and retain the parent scroll position', (tester) async {
    const mobile = Size(400, 900);
    tester.view.physicalSize = mobile;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late BuildContext parentContext;
    const parentList = ValueKey('parent-list');
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSheet<void>(
              context: context,
              props: const SheetProps(
                backgroundColor: Colors.transparent,
                retainExpandedHeight: true,
              ),
              builder: (_) => NestedPagedSheet(
                builder: (context) {
                  parentContext = context;
                  return Scaffold(
                    title: 'Parent',
                    body: ListView.builder(
                      key: parentList,
                      shrinkWrap: true,
                      itemCount: 40,
                      itemBuilder: (_, index) =>
                          SizedBox(height: 40, child: Text('row $index')),
                    ),
                  );
                },
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    ProviderScope.containerOf(
      tester.element(find.text('Open')),
    ).read(viewSizeProvider.notifier).value = mobile;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    Rect frame() {
      final clip = tester.layers.whereType<ClipRSuperellipseLayer>().firstWhere(
        (layer) =>
            layer.clipRSuperellipse!.width == mobile.width &&
            layer.parent is TransformLayer,
      );
      return MatrixUtils.transformRect(
        (clip.parent! as TransformLayer).transform!,
        clip.clipRSuperellipse!.outerRect,
      );
    }

    void push(double height) => Navigator.of(parentContext).push<void>(
      PagedSheetRoute(
        builder: (_) => Scaffold(
          title: 'Child',
          body: ListView(
            shrinkWrap: true,
            children: [
              SizedBox(height: height, child: const Text('Child body')),
            ],
          ),
        ),
      ),
    );

    final compact = frame();
    expect(compact.left, closeTo(sheetFloatInset, 0.1));
    expect(compact.bottom, closeTo(mobile.height - sheetFloatInset, 0.1));
    push(100);
    await tester.pumpAndSettle();
    expect(frame(), compact);
    Navigator.of(parentContext).pop();
    await tester.pumpAndSettle();

    await tester.dragFrom(
      tester.getCenter(find.byType(SheetDragHandle)),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    final expanded = frame();
    expect(expanded.left, closeTo(0, 0.1));
    expect(expanded.right, closeTo(mobile.width, 0.1));
    expect(expanded.bottom, closeTo(mobile.height, 0.1));
    await tester.drag(find.byKey(parentList), const Offset(0, -120));
    await tester.pumpAndSettle();
    final scroll = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(parentList),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    final offset = scroll.pixels;
    expect(offset, greaterThan(0));
    for (final height in [100.0, 640.0]) {
      push(height);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(frame().top, closeTo(expanded.top, 0.1));
        expect(frame().left, closeTo(0, 0.1));
        expect(frame().bottom, closeTo(mobile.height, 0.1));
      }
      await tester.pumpAndSettle();
      Navigator.of(parentContext).pop();
      await tester.pumpAndSettle();
      expect(frame(), expanded);
      expect(scroll.pixels, offset);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
