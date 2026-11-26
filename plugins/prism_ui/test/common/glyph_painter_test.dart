import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/icons/icons.dart';

bool _paintsIntoLayer(
  Glyph glyph, {
  required double fill,
  required Color color,
}) {
  final canvas = TestRecordingCanvas();
  GlyphPainter(
    glyph: glyph,
    fill: fill,
    color: color,
  ).paint(canvas, const Size.square(Glyph.size));
  return canvas.invocations.any(
    (call) => call.invocation.memberName == #saveLayer,
  );
}

void main() {
  const opaque = Color(0xFF336699);

  test('a filled glyph with nothing to cut out paints without a layer', () {
    expect(_paintsIntoLayer(Glyphs.caretDown, fill: 1, color: opaque), isFalse);
    expect(_paintsIntoLayer(Glyphs.caretDown, fill: 0, color: opaque), isFalse);
  });

  test('a filled glyph cuts its details out of a layer of its own', () {
    expect(_paintsIntoLayer(Glyphs.eye, fill: 1, color: opaque), isTrue);
    expect(_paintsIntoLayer(Glyphs.eye, fill: 0, color: opaque), isFalse);
  });

  test('a translucent glyph paints into a layer whatever its fill', () {
    final translucent = opaque.withValues(alpha: 0.5);
    expect(
      _paintsIntoLayer(Glyphs.caretDown, fill: 1, color: translucent),
      isTrue,
    );
    expect(
      _paintsIntoLayer(Glyphs.caretDown, fill: 0, color: translucent),
      isTrue,
    );
  });
}
