import 'dart:ui' show ImageFilter;

import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';

class MiuixFrostedSection extends StatelessWidget {
  const MiuixFrostedSection({
    super.key,
    this.title,
    required this.items,
    this.blurEnabled = true,
  });

  final String? title;
  final List<Widget> items;
  final bool blurEnabled;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          ListHeader(title: title!)
        else
          const ListSectionGap(),
        MiuixFrostedCard(items: items, blurEnabled: blurEnabled),
      ],
    );
  }
}

class MiuixFrostedCard extends StatelessWidget {
  const MiuixFrostedCard({
    super.key,
    required this.items,
    this.blurEnabled = true,
  });

  final List<Widget> items;
  final bool blurEnabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    // Miuix AboutPage uses Pured_Regular_Light (~0xB3FFFFFF tint) in light mode
    // and translucent surfaceContainer with soft highlight edge in dark mode.
    final fillColor = isDark
        ? colorScheme.surfaceContainer.withValues(alpha: 0.62)
        : const Color(0xB8FFFFFF);
    final borderColor = isDark
        ? const Color(0x22FFFFFF)
        : const Color(0x99FFFFFF);
    const shape = AppShape.xl;
    final body = DecoratedBox(
      decoration: ShapeDecoration(color: fillColor, shape: shape),
      child: ListCardFillScope(
        fill: const Color(0x00000000),
        child: generateGroup(items),
      ),
    );
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: SuperellipseBorder(
          borderRadius: AppRadius.xl,
          side: BorderSide(color: borderColor, width: 0.8),
        ),
      ),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: shape),
        child: blurEnabled
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: body,
              )
            : body,
      ),
    );
  }
}
