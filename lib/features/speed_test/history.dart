import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gauge.dart';
import 'store.dart';
import 'widgets.dart';

String _date(SpeedTestRecord record) =>
    DateTime.fromMillisecondsSinceEpoch(record.time).showFull;

class SpeedTestHistoryView extends ConsumerWidget {
  const SpeedTestHistoryView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final data = ref.watch(speedTestStoreProvider);
    final records = data.value?.records ?? const <SpeedTestRecord>[];
    return SpeedTestScope(
      child: Scaffold(
        title: l.speedTestHistory,
        iconActions: [
          IconButtonData(
            glyph: AppGlyphs.delete,
            tooltip: l.delete,
            onPressed: records.isEmpty
                ? null
                : () async {
                    final clear = await dialogs.showMessage(
                      message: TextSpan(text: l.speedTestClearHistoryTip),
                      destructive: true,
                      confirmText: l.delete,
                    );
                    if (clear == true) {
                      await ref.read(speedTestStoreProvider.notifier).clear();
                    }
                  },
          ),
        ],
        body: Builder(
          builder: (context) => NullStatusSwitcher(
            isLoading: data.isLoading,
            isEmpty: records.isEmpty,
            nullStatus: NullStatus(
              label: l.speedTestHistoryEmpty,
              illustration: NullStatusIllustration.ntp,
            ),
            child: PrismListView(
              padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
                top: context.contentTopPadding + 12,
                bottom: 20 + context.bottomInset,
              ),
              itemCount: records.length + 1,
              itemBuilder: (context, index) {
                if (index == records.length) {
                  return ListFooter(text: l.speedTestHistoryRetention);
                }
                final record = records[index];
                final s = record.result;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ItemPositionProvider(
                    position: ItemPosition.startAndEnd,
                    child: DecorationListItem(
                      leading: const GlyphIcon(AppGlyphs.speed),
                      title: Text(_date(record)),
                      subtitle: Text(
                        '↓ ${speedTestValue(s.download)} ${speedTestUnit(s.download)}   ↑ ${speedTestValue(s.upload)} ${speedTestUnit(s.upload)}',
                      ),
                      trailing: const GlyphIcon(AppGlyphs.chevronForward),
                      onPressed: () => Navigator.of(context).push(
                        PagedSheetRoute(
                          builder: (_) => SpeedTestRecordView(record: record),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class SpeedTestRecordView extends StatelessWidget {
  const SpeedTestRecordView({super.key, required this.record});
  final SpeedTestRecord record;
  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final result = record.result;
    final chains = result.outbound?.chains ?? const <String>[];
    final server = result.server;
    final exitNode = chains.isNotEmpty
        ? chains.last
        : record.proxy.isEmpty
        ? l.speedTestFollowRules
        : record.proxy;
    final serverText = server == null
        ? ''
        : [
            server.sponsor,
            server.city,
          ].where((s) => s.isNotEmpty).join(' · ');
    return SpeedTestScope(
      child: Scaffold(
        title: l.speedTestHistory,
        body: Builder(
          builder: (context) => ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
              top: context.contentTopPadding + 12,
              bottom: 20 + context.bottomInset,
            ),
            children: [
              Card(
                radius: AppCorner.xl,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_date(record), style: AppTextStyle.headline.of(context)),
                    const SizedBox(height: 24),
                    SpeedTestMetrics(state: result),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: const ValueKey('speed-record-details'),
                child: generateGroup([
                  DetailRow(
                    title: l.speedTestExitNode,
                    value: EmojiText(exitNode),
                    copyText: exitNode,
                  ),
                  if (serverText.isNotEmpty)
                    DetailRow.text(
                      title: l.speedTestServer,
                      value: serverText,
                    ),
                  DetailRow.text(
                    title: l.speedTestProtocol,
                    value: speedProtocolLabel(result.protocol),
                  ),
                  DetailRow.text(
                    title: l.speedTestDataUsed,
                    value: speedTestBytes(result.bytes),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
