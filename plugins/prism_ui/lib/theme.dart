import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:prism_ui/common_button.dart';
import 'package:prism_ui/metrics.dart';
import 'package:prism_ui/theme_data.dart';

class MinFilledButtonTheme extends StatelessWidget {
  final Widget child;

  const MinFilledButtonTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ButtonTheme.merge(
      data: const ButtonThemeData(
        filled: ButtonStyle(
          padding: EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: TapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      child: child,
    );
  }
}

class MinIconButtonTheme extends StatelessWidget {
  final Widget child;

  const MinIconButtonTheme({super.key, required this.child});

  static const _padding = 4.0;

  static double _glyphSizeOf(BuildContext context) => 20.ap(context);

  /// What a button under this theme leaves beside its glyph: the compact
  /// 32 minimum, or the padding once the glyph outgrows it.
  static double edgeInsetOf(BuildContext context) {
    final glyph = _glyphSizeOf(context);
    final minimum =
        IconButton.minimumSize + VisualDensity.compact.baseSizeAdjustment.dx;
    return (math.max(minimum, glyph + 2 * _padding) - glyph) / 2;
  }

  @override
  Widget build(BuildContext context) {
    return ButtonTheme.merge(
      data: ButtonThemeData(
        icon: ButtonStyle(
          padding: const EdgeInsets.symmetric(horizontal: _padding),
          visualDensity: VisualDensity.compact,
          tapTargetSize: TapTargetSize.shrinkWrap,
          iconSize: _glyphSizeOf(context),
        ),
      ),
      child: child,
    );
  }
}
