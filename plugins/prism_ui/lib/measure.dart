import 'package:flutter/widgets.dart';
import 'package:prism_ui/list_text.dart';
import 'package:prism_ui/metrics.dart';
import 'package:prism_ui/typography.dart';

typedef _TextMeasureKey = (String?, TextStyle?, int?, TextDirection?, double?);

class Measure {
  static const _textMeasureCacheLimit = 512;

  final TextScaler _textScaler;
  final BuildContext context;
  final Map<_TextMeasureKey, Size> _textSizeCache = {};

  Measure.of(this.context, double textScaleFactor)
    : _textScaler = TextScaler.linear(textScaleFactor);

  TextPainter _computeText(Text text, {double? maxWidth}) {
    return TextPainter(
      text: TextSpan(text: text.data, style: text.style),
      maxLines: text.maxLines,
      textScaler: _textScaler,
      ellipsis: '...',
      locale: Localizations.localeOf(context),
      textDirection: text.textDirection ?? TextDirection.ltr,
    )..layout(maxWidth: maxWidth ?? double.infinity);
  }

  R _measuring<R>(
    Text text,
    double? maxWidth,
    R Function(TextPainter painter) read,
  ) {
    final textPainter = _computeText(text, maxWidth: maxWidth);
    try {
      return read(textPainter);
    } finally {
      textPainter.dispose();
    }
  }

  _TextMeasureKey _measureKey(Text text, double? maxWidth) {
    return (text.data, text.style, text.maxLines, text.textDirection, maxWidth);
  }

  R _cached<R extends Object>(
    Map<_TextMeasureKey, R> cache,
    _TextMeasureKey key,
    R Function() compute,
  ) {
    final cachedValue = cache[key];
    if (cachedValue != null) {
      return cachedValue;
    }
    if (cache.length >= _textMeasureCacheLimit) {
      cache.clear();
    }
    return cache[key] = compute();
  }

  Size computeTextSize(Text text) {
    return _cached(
      _textSizeCache,
      _measureKey(text, null),
      () => _measuring(text, null, (painter) => painter.size),
    );
  }

  final Map<AppTextStyle, double> _textHeights = {};

  double textHeight(AppTextStyle style) => _textHeights[style] ??=
      computeTextSize(Text('X', style: style.of(context))).height;

  double listTitleHeight([ListTextScale scale = ListTextScale.regular]) =>
      textHeight(scale.title);

  double listSubtitleHeight([ListTextScale scale = ListTextScale.regular]) =>
      textHeight(scale.subtitle);

  double get cardHeaderHeight => textHeight(AppTextStyle.headline);

  double listRowHeight([ListTextScale scale = ListTextScale.regular]) =>
      listRowExtent(titleHeight: listTitleHeight(scale));

  double listTwoLineRowHeight([ListTextScale scale = ListTextScale.regular]) =>
      listRowExtent(
        titleHeight: listTitleHeight(scale),
        subtitleHeight: listSubtitleHeight(scale),
      );
}

extension ListRowHeightContext on BuildContext {
  /// The least a row stands, so one that drops its padding still stands as
  /// tall as a padded line of its title.
  double get listRowHeight =>
      MeasureScope.of(this).listRowHeight(ListTextScope.of(this));
}

class MeasureScope extends InheritedWidget {
  const MeasureScope({super.key, required this.measure, required super.child});

  final Measure measure;

  static Measure of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<MeasureScope>()
        : context.getInheritedWidgetOfExactType<MeasureScope>();
    assert(scope != null, 'No MeasureScope found above $context.');
    return scope!.measure;
  }

  @override
  bool updateShouldNotify(MeasureScope oldWidget) =>
      measure != oldWidget.measure;
}
