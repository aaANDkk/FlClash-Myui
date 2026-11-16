import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ip.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'risk_model.dart';
import 'risk_provider.dart';
import 'risk_view.dart';

Future<void> showIpQualitySheet(
  BuildContext context, {
  required String ip,
  bool outbound = true,
}) {
  Widget page(BuildContext context) => IpRiskSheet(ip: ip, outbound: outbound);
  if (isSheetPage(context)) {
    return Navigator.of(context).push(PagedSheetRoute(builder: page));
  }
  return showSheet<void>(context: context, builder: page);
}

class IpRiskSheet extends ConsumerStatefulWidget {
  const IpRiskSheet({super.key, required this.ip, this.outbound = true});
  final String ip;
  final bool outbound;

  @override
  ConsumerState<IpRiskSheet> createState() => _IpRiskSheetState();
}

class _IpRiskSheetState extends ConsumerState<IpRiskSheet> {
  late String _ip = widget.ip;
  bool _retrying = false;
  bool _retryHold = false;
  Timer? _retryTimer;

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _editIp() async {
    final l = context.appLocalizations;
    final value = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: l.ipRiskHint,
        value: ref.read(appSettingProvider).hideIp ? '' : _ip,
        validator: (v) => publicIpOf(v ?? '') == null ? l.ipRiskInvalid : null,
      ),
    );
    if (!mounted || value == null) return;
    final ip = publicIpOf(value);
    if (ip != null && ip != _ip) {
      _retryTimer?.cancel();
      setState(() {
        _ip = ip;
        _retrying = false;
        _retryHold = false;
      });
    }
  }

  void _retry() {
    if (_retryHold) return;
    _retryTimer?.cancel();
    setState(() {
      _retrying = true;
      _retryHold = true;
    });
    _retryTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _retryHold = false);
    });
    ref.invalidate(ipRiskProvider(_ip));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final state = ref.watch(ipRiskProvider(_ip));
    final isLoading = state.isLoading && !state.hasValue;
    final risk = state.hasError ? null : state.value;
    final hidden = ref.watch(appSettingProvider.select((s) => s.hideIp));
    return Theme(
      data: Theme.of(context).copyWith(visualDensity: VisualDensity.standard),
      child: Scaffold(
        title: widget.outbound ? l.outboundIp : l.ipDetails,
        iconActions: [
          IconButtonData(
            glyph: hidden ? AppGlyphs.eyeOff : AppGlyphs.eye,
            tooltip: l.hideIp,
            onPressed: () => ref
                .read(appSettingProvider.notifier)
                .update((s) => s.copyWith(hideIp: !hidden)),
          ),
        ],
        body: Builder(
          builder: (context) => NullStatusSwitcher(
            key: ValueKey(_ip),
            isLoading: !_retrying && isLoading,
            holdsArrival: false,
            loadingStatus: const Center(child: ActivityIndicator.page()),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                context.contentTopPadding + 12,
                16,
                20 + context.bottomInset,
              ),
              children: [
                Card(
                  radius: AppCorner.xl,
                  child: ListItem(
                    leading: const GlyphIcon(AppGlyphs.proxies),
                    title: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.ipAddress,
                          style: AppTextStyle.footnote
                              .of(context)
                              .copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hidden ? '*****' : _ip,
                          style: hidden
                              ? AppTextStyle.headline
                                    .of(context, emphasized: true)
                                    .toJetBrainsMono
                              : AppTextStyle.headline.of(
                                  context,
                                  emphasized: true,
                                ),
                        ),
                      ],
                    ),
                    trailing: MinIconButtonTheme(
                      child: IconButton(
                        tooltip: l.edit,
                        onPressed: _editIp,
                        icon: const GlyphIcon(AppGlyphs.edit, size: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: context.motionDuration(commonDuration),
                  reverseDuration: context.motionDuration(
                    const Duration(milliseconds: 150),
                  ),
                  switchInCurve: Easing.emphasizedDecelerate,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (currentChild, previousChildren) => Align(
                    alignment: Alignment.topCenter,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[...previousChildren, ?currentChild],
                    ),
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child.key == const ValueKey('data')
                        ? ScaleTransition(
                            scale: animation.drive(
                              Tween(begin: 0.92, end: 1.0),
                            ),
                            child: child,
                          )
                        : child,
                  ),
                  child: _buildBody(
                    context,
                    isLoading: isLoading,
                    risk: risk,
                    hidden: hidden,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required IpRisk? risk,
    required bool hidden,
  }) {
    final l = context.appLocalizations;
    if (!isLoading && risk != null) {
      return Column(
        key: const ValueKey('data'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RiskScoreCard(risk: risk),
          const SizedBox(height: 12),
          if (risk.checks.isNotEmpty) ...[
            RiskChecksCard(risk: risk),
            const SizedBox(height: 12),
          ],
          _LocationCard(risk: risk, hidden: hidden),
          ListFooter(text: '${l.ipRiskSource} Scamalytics'),
        ],
      );
    }
    return SizedBox(
      key: const ValueKey('error'),
      width: double.infinity,
      child: Card(
        radius: AppCorner.xl,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlyphIcon(
              AppGlyphs.error,
              size: 28,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              l.ipRiskFailed,
              textAlign: TextAlign.center,
              style: AppTextStyle.body
                  .of(context)
                  .copyWith(color: context.colorScheme.error),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FadeBox(
                child: isLoading || _retryHold
                    ? const SizedBox(
                        key: ValueKey('spinner'),
                        height: 48,
                        child: Center(child: ActivityIndicator(size: 20)),
                      )
                    : FilledButton.icon(
                        key: const ValueKey('retry'),
                        onPressed: _retry,
                        icon: const GlyphIcon(AppGlyphs.refresh, size: 18),
                        label: Text(l.retry),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.risk, required this.hidden});
  final IpRisk risk;
  final bool hidden;

  Widget _value(
    BuildContext context,
    String title,
    String value, {
    bool emoji = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: AppTextStyle.footnote
            .of(context)
            .copyWith(color: context.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 6),
      if (emoji)
        EmojiText(value, style: AppTextStyle.body.of(context, emphasized: true))
      else
        SelectableText(
          value,
          style: hidden && value.contains('*****')
              ? AppTextStyle.body.of(context, emphasized: true).toJetBrainsMono
              : AppTextStyle.body.of(context, emphasized: true),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final country = risk.countryLabel ?? '';
    final place = risk.placeLabel ?? '';
    final hasLocation = country.isNotEmpty || place.isNotEmpty;
    final showAsnPill = hasLocation && risk.asn.isNotEmpty;
    final owner = showAsnPill
        ? risk.organization
        : [
            risk.organization,
            risk.asn,
          ].where((s) => s.isNotEmpty).join(' \u00b7 ');
    final rows = <Widget>[
      if (hasLocation)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    country.isNotEmpty ? l.ipRiskLocation : l.ipRiskCity,
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (country.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    EmojiText(
                      country,
                      style: AppTextStyle.headline.of(
                        context,
                        emphasized: true,
                      ),
                    ),
                  ],
                  if (place.isNotEmpty) ...[
                    SizedBox(height: country.isNotEmpty ? 4 : 6),
                    SelectableText(
                      place,
                      style: country.isNotEmpty
                          ? AppTextStyle.subheadline
                                .of(context)
                                .copyWith(color: cs.onSurfaceVariant)
                          : AppTextStyle.body.of(context, emphasized: true),
                    ),
                  ],
                ],
              ),
            ),
            if (showAsnPill) ...[
              const SizedBox(width: 12),
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: DashboardColors.of(context).tone,
                  shape: AppShape.full,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  child: Text(
                    risk.asn,
                    style: AppTextStyle.footnote
                        .of(context, emphasized: true)
                        .toTabular
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ],
        ),
      if (owner.isNotEmpty)
        _value(
          context,
          showAsnPill ? l.ipOrganization : l.operatorOrAsn,
          owner,
        ),
      if (risk.isp.isNotEmpty && risk.isp != risk.organization)
        _value(context, l.isp, risk.isp),
      if (!hidden && risk.hostname.isNotEmpty)
        _value(context, l.ipRiskHostname, risk.hostname),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      radius: AppCorner.xl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) ...[
              const SizedBox(height: 14),
              Divider(
                height: 1,
                thickness: Divider.separatorThicknessOf(context),
              ),
              const SizedBox(height: 14),
            ],
            row,
          ],
        ],
      ),
    );
  }
}
