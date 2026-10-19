import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'card.dart';

Glyph _glyphOf(Mode mode) => switch (mode) {
  Mode.rule => AppGlyphs.rules,
  Mode.global => AppGlyphs.proxies,
  Mode.direct => AppGlyphs.target,
};

void _changeMode(WidgetRef ref, Mode mode) {
  if (ref.read(patchClashConfigProvider).mode == mode) return;
  ref.read(setupActionProvider.notifier).changeMode(mode);
}

class OutboundModeCard extends StatelessWidget {
  const OutboundModeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const OutboundModeBar();
  }
}

/// Outbound mode switch bar that puts "出站模式" and the mode buttons
/// in the same horizontal row for both portrait and landscape layouts.
class OutboundModeBar extends ConsumerWidget {
  const OutboundModeBar({super.key});

  static const _inset = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = DashboardDensityScope.of(context);
    final scale = DashboardDensityScope.scaleOf(context);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final appLocalizations = context.appLocalizations;
    final outer = dashboardCardRadius(density) - _inset;
    final buttonHeight = (density.isCompact ? 40.0 : 44.0) * scale;
    final style = AppTextStyle.subheadline.of(context, emphasized: true);
    return DashboardCard(
      semanticLabel: appLocalizations.outboundMode,
      padding: EdgeInsetsDirectional.fromSTEB(
        dashboardCardPadding(density).left,
        _inset,
        _inset,
        _inset,
      ),
      child: SizedBox(
        height: buttonHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GlyphIcon(
              AppGlyphs.split,
              size: 18,
              color: context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              appLocalizations.outboundMode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DashboardText.cardTitle(context).copyWith(fontSize: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DashboardConnectedGroup(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, item) in Mode.values.indexed)
                    Expanded(
                      child: DashboardConnectedButton(
                        selected: item == mode,
                        first: index == 0,
                        last: index == Mode.values.length - 1,
                        outer: outer,
                        inner: 10,
                        background: DashboardColors.of(context).tone,
                        semanticLabel: item.label,
                        onTap: () => _changeMode(ref, item),
                        builder: (foreground) => SizedBox(
                          height: buttonHeight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlyphIcon(
                                _glyphOf(item),
                                size: 16,
                                color: foreground,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: style.copyWith(
                                    color: foreground,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
