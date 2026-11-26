import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/context.dart';
import 'package:prism_ui/metrics.dart';
import 'package:prism_ui/shape.dart';
import 'package:prism_ui/surface.dart';
import 'package:prism_ui/theme_data.dart';

/// Shares of a whole as one pill, each segment as wide as its part, on the
/// track alone while no part comes to a whole percent of it.
class ProportionBar extends StatelessWidget {
  const ProportionBar({super.key, required this.segments});

  static const _gap = 2.0;
  static const _height = 8.0;

  final List<({int value, Color color})> segments;

  @override
  Widget build(BuildContext context) {
    final duration = context.motionDuration(commonDuration);
    final total = segments.fold(
      0,
      (sum, segment) => sum + max(0, segment.value),
    );
    // Whole percents, so the drift between two polls does not replay the
    // animation every time.
    final percents = [
      for (final segment in segments)
        total == 0
            ? 0.0
            : (max(0, segment.value) * 100 / total).roundToDouble(),
    ];
    return ClipRSuperellipse(
      borderRadius: AppRadius.full,
      child: SizedBox(
        height: _height,
        child: percents.every((percent) => percent == 0)
            ? ColoredBox(color: SurfaceLevel.inset.colorOf(context.colorScheme))
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, segment) in segments.indexed) ...[
                    if (index > 0)
                      AnimatedContainer(
                        duration: duration,
                        curve: Easing.standard,
                        width:
                            percents[index] > 0 &&
                                percents.take(index).any((shown) => shown > 0)
                            ? _gap
                            : 0,
                      ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: percents[index]),
                      duration: duration,
                      curve: Easing.standard,
                      builder: (_, percent, child) => Expanded(
                        flex: (percent * 100).round(),
                        child: child!,
                      ),
                      child: ColoredBox(color: segment.color),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
