import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client.dart';
import 'store.dart';
import 'widgets.dart';

class TrafficStatsSettingsView extends ConsumerWidget {
  const TrafficStatsSettingsView({super.key, this.onCleared});

  final VoidCallback? onCleared;

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      message: TextSpan(text: l.trafficStatsClearTip),
      destructive: true,
      confirmText: l.clearData,
    );
    if (confirmed != true) return;
    await ref.read(trafficStatsClientProvider).clear();
    onCleared?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final settings =
        ref.watch(trafficStatsStoreProvider).value ??
        const TrafficStatsSettings();
    final notifier = ref.read(trafficStatsStoreProvider.notifier);

    return TrafficStatsScope(
      child: Scaffold(
        title: l.trafficStatsSettings,
        body: Builder(
          builder: (context) => ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
              top: context.sectionsTopPadding,
              bottom: 20 + context.bottomInset,
            ),
            children: [
              generateSection(
                items: [
                  ListItem.toggle(
                    title: Text(l.trafficStatsEnable),
                    value: settings.enable,
                    onChanged: (value) => notifier.updateSettings(
                      (s) => s.copyWith(enable: value),
                    ),
                  ),
                ],
              ),
              generateSection(
                title: l.general,
                items: [
                  ListItem.toggle(
                    title: Text(l.trafficStatsDetail),
                    subtitle: Text(l.trafficStatsDetailDesc),
                    value: settings.detail,
                    onChanged: (value) => notifier.updateSettings(
                      (s) => s.copyWith(detail: value),
                    ),
                  ),
                  ListItem.toggle(
                    title: Text(l.trafficStatsSiteIcon),
                    subtitle: Text(l.trafficStatsSiteIconDesc),
                    value: settings.siteIcon,
                    onChanged: (value) => notifier.updateSettings(
                      (s) => s.copyWith(siteIcon: value),
                    ),
                  ),
                  ListItem<int>.options(
                    title: Text(l.trafficStatsRetention),
                    options: trafficStatsRetentionOptions,
                    value: trafficStatsRetentionOptions.contains(
                      settings.retentionDays,
                    )
                        ? settings.retentionDays
                        : 30,
                    textBuilder: (value) => l.trafficStatsDays(value),
                    onChanged: (value) => notifier.updateSettings(
                      (s) => s.copyWith(retentionDays: value),
                    ),
                  ),
                ],
              ),
              generateSection(
                title: l.action,
                items: [
                  ListItem(
                    leading: GlyphIcon(AppGlyphs.delete, color: cs.error),
                    title: Text(
                      l.clearData,
                      style: AppTextStyle.body
                          .of(context)
                          .copyWith(color: cs.error),
                    ),
                    onTap: () => _confirmClear(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
