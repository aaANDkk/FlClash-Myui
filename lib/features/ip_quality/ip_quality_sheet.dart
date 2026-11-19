import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ip_locate.dart';
import 'risk_model.dart';
import 'risk_provider.dart';
import 'risk_view.dart';

Future<void> showIpQualitySheet(
  BuildContext context, {
  String ip = '',
  String? proxyName,
  bool outbound = true,
}) {
  Widget page(BuildContext context) =>
      IpRiskSheet(ip: ip, proxyName: proxyName, outbound: outbound);
  if (isSheetPage(context)) {
    return Navigator.of(context).push(PagedSheetRoute(builder: page));
  }
  return showSheet<void>(context: context, builder: page);
}

class IpRiskSheet extends ConsumerStatefulWidget {
  const IpRiskSheet({
    super.key,
    this.ip = '',
    this.proxyName,
    this.outbound = true,
  }) : assert(ip != '' || proxyName != null);
  final String ip;
  final String? proxyName;
  final bool outbound;

  @override
  ConsumerState<IpRiskSheet> createState() => _IpRiskSheetState();
}

class _IpRiskSheetState extends ConsumerState<IpRiskSheet> {
  bool _retrying = false;
  bool _retryHold = false;
  Timer? _retryTimer;

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _retry(
    String effectiveIp, {
    required bool riskFailed,
    required bool attributionFailed,
  }) {
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
    if (effectiveIp.isEmpty && widget.proxyName != null) {
      ref.invalidate(proxyExitIpProvider(widget.proxyName!));
    } else if (effectiveIp.isNotEmpty) {
      if (riskFailed) refreshIpRisk(ref, effectiveIp);
      if (attributionFailed) ref.invalidate(ipLocateProvider(effectiveIp));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final proxyIpState = widget.ip.isEmpty && widget.proxyName != null
        ? ref.watch(proxyExitIpProvider(widget.proxyName!))
        : null;
    final resolvingIp =
        proxyIpState != null &&
        proxyIpState.isLoading &&
        !proxyIpState.hasValue;
    final resolvedIp = proxyIpState != null && !proxyIpState.hasError
        ? (proxyIpState.value ?? '')
        : '';
    final effectiveIp = widget.ip.isNotEmpty ? widget.ip : resolvedIp;
    final state = effectiveIp.isNotEmpty
        ? ref.watch(ipRiskProvider(effectiveIp))
        : null;
    final attributionState = effectiveIp.isNotEmpty
        ? ref.watch(ipLocateProvider(effectiveIp))
        : null;
    final risk = state == null || state.hasError ? null : state.value;
    final attribution = attributionState == null || attributionState.hasError
        ? null
        : attributionState.value;
    final riskFailed = state != null && !state.isLoading && risk == null;
    final attributionFailed =
        attributionState != null &&
        !attributionState.isLoading &&
        attribution == null;
    final isLoading =
        resolvingIp ||
        (!riskFailed &&
            !attributionFailed &&
            ((state?.isLoading ?? false) ||
                (attributionState?.isLoading ?? false)));
    final hidden = ref.watch(appSettingProvider.select((s) => s.hideIp));
    final switchKey = widget.proxyName ?? effectiveIp;
    return Theme(
      data: Theme.of(context).copyWith(visualDensity: VisualDensity.standard),
      child: Scaffold(
        title: widget.proxyName != null
            ? l.ipRiskCheck
            : (widget.outbound ? l.outboundIp : l.ipDetails),
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
            key: ValueKey(switchKey),
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
                    leading: const GlyphIcon(AppGlyphs.location),
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
                          hidden
                              ? '*****'
                              : (effectiveIp.isNotEmpty ? effectiveIp : '--'),
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
                        tooltip: l.copy,
                        onPressed: effectiveIp.isEmpty
                            ? null
                            : () =>
                                  dialogs.copyToClipboard(context, effectiveIp),
                        icon: const GlyphIcon(AppGlyphs.copy, size: 16),
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
                    attribution: attribution,
                    hidden: hidden,
                    onRetry: () => _retry(
                      effectiveIp,
                      riskFailed: riskFailed,
                      attributionFailed: attributionFailed,
                    ),
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
    required IpLocateInfo? attribution,
    required bool hidden,
    required VoidCallback onRetry,
  }) {
    final l = context.appLocalizations;
    if (!isLoading && risk != null && attribution != null) {
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
          _LocationCard(risk: risk, attribution: attribution, hidden: hidden),
          ListFooter(text: '${l.ipRiskSource} ${l.ipRiskSources}'),
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
                        onPressed: onRetry,
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
  const _LocationCard({
    required this.risk,
    required this.attribution,
    required this.hidden,
  });
  final IpRisk risk;
  final IpLocateInfo? attribution;
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
    final info = attribution?.ip == risk.ip ? attribution : null;
    final company = info?.company ?? '';
    final network = info?.network ?? '';
    final asn = info?.asn ?? '';
    final showAsnPill = asn.isNotEmpty;
    final rows = <Widget>[
      if (hasLocation || showAsnPill)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasLocation)
                  Expanded(
                    child: Text(
                      country.isNotEmpty ? l.ipRiskLocation : l.ipRiskCity,
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  )
                else
                  const Spacer(),
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
                        asn,
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
            if (country.isNotEmpty) ...[
              const SizedBox(height: 6),
              EmojiText(
                country,
                style: AppTextStyle.headline.of(context, emphasized: true),
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
      if (company.isNotEmpty) _value(context, l.isp, company),
      if (network.isNotEmpty && network != company)
        _value(context, l.ipRiskAsn, network),
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
