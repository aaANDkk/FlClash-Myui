import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The visible glyph bounds, relative to the alphabetic baseline.
class TextInk {
  const TextInk(this.ascent, this.descent);

  final double ascent;
  final double descent;

  double get height => ascent + descent;
}

const _inkSampling = 4.0;
const _inkThreshold = 128;

/// Measures a line's visible glyphs using the same font and scaling as its text.
Future<TextInk?> measureTextInk(
  String text,
  TextStyle style,
  TextScaler scaler, {
  TextDirection textDirection = TextDirection.ltr,
  Locale? locale,
}) async {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: style.copyWith(color: const Color(0xFF000000)),
    ),
    textDirection: textDirection,
    textScaler: scaler,
    locale: locale,
    maxLines: 1,
  )..layout();
  final baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  final pad = scaler.scale(style.fontSize ?? 14) * 0.5;
  final width = ((painter.width + pad * 2) * _inkSampling).ceil();
  final height = ((painter.height + pad * 2) * _inkSampling).ceil();
  if (width <= 0 || height <= 0) {
    painter.dispose();
    return null;
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_inkSampling);
  painter.paint(canvas, Offset(pad, pad));
  painter.dispose();

  final picture = recorder.endRecording();
  final ByteData? data;
  try {
    final image = await picture.toImage(width, height);
    try {
      data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
  if (data == null) return null;

  int? top;
  int? bottom;
  for (var y = 0; y < height; y++) {
    final row = y * width * 4;
    for (var x = 0; x < width; x++) {
      if (data.getUint8(row + x * 4 + 3) >= _inkThreshold) {
        top ??= y;
        bottom = y;
        break;
      }
    }
  }
  if (top == null || bottom == null) return null;

  final inkTop = top / _inkSampling - pad;
  final inkBottom = (bottom + 1) / _inkSampling - pad;
  return TextInk(baseline - inkTop, inkBottom - baseline);
}

/// Reports [baseline] as its child's alphabetic baseline, so a box with no
/// text of its own can sit on a [Row]'s shared baseline.
class BaselineAt extends SingleChildRenderObjectWidget {
  const BaselineAt({required this.baseline, super.child});

  final double baseline;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBaselineAt(baseline);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBaselineAt renderObject,
  ) {
    renderObject.baseline = baseline;
  }
}

class _RenderBaselineAt extends RenderProxyBox {
  _RenderBaselineAt(this._baseline);

  double _baseline;

  set baseline(double value) {
    if (value == _baseline) {
      return;
    }
    _baseline = value;
    markNeedsLayout();
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _baseline;

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _baseline;
}
