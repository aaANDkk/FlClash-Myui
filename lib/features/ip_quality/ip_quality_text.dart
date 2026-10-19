import 'package:fl_clash/manager/emoji_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'labels.dart';

class IpQualityText extends ConsumerWidget {
  const IpQualityText({super.key, required this.ip, this.style, this.leading});

  final String ip;
  final TextStyle? style;

  /// An emoji that leads the address in the same paragraph, so the two share one
  /// baseline instead of the emoji carrying a line box of its own.
  final String? leading;

  static const _mask = '*****';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality = ref.watch(ipQualityProvider(ip)).value;
    final hideIp = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    final shownIp = hideIp ? _mask : ip;
    final color = quality?.level.color(context);
    var style = this.style;
    if (hideIp) {
      style = (style ?? const TextStyle()).toJetBrainsMono;
    }
    if (color != null) {
      style = (style ?? const TextStyle()).copyWith(color: color);
    }
    final leading = this.leading;
    return Tooltip(
      preferBelow: false,
      message: shownIp,
      child: leading == null || leading.isEmpty
          ? Text(
              shownIp,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : ValueListenableBuilder<EmojiStyle>(
              valueListenable: EmojiManager.emojiStyleNotifier,
              builder: (context, emojiStyle, _) => Text.rich(
                TextSpan(
                  children: [
                    ...?EmojiText.spanOf(
                      '$leading ',
                      null,
                      emojiFamily: emojiStyle.family,
                    ).children,
                    TextSpan(text: shownIp, style: style),
                  ],
                ),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
    );
  }
}
