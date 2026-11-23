import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/country_flags.dart';
import 'package:fl_clash/common/country_names.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/features/ip_quality/risk_provider.dart';
import 'package:fl_clash/features/ip_quality/risk_model.dart';
import 'package:fl_clash/features/ip_quality/risk_view.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/text_ink.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:prism_ui/shapes/shapes.dart';

import 'card.dart';

const _builtinOutbounds = {'DIRECT', 'REJECT', 'REJECT-DROP', 'PASS'};

bool isBuiltinOutbound(String name) => _builtinOutbounds.contains(name);

const _ipMask = '*****';

const _decorationGrowth = 0.06;

const _decorationTurn = 2 * math.pi / 12;

const _decorationBottomGap = 10.0;

/// The address the proxied traffic leaves by, next to the start button.
class CurrentOutboundCard extends ConsumerStatefulWidget {
  const CurrentOutboundCard({super.key});

  @override
  ConsumerState<CurrentOutboundCard> createState() =>
      _CurrentOutboundCardState();
}

class _CurrentOutboundCardState extends ConsumerState<CurrentOutboundCard> {
  late final OutboundIpProbe _probe;

  @override
  void initState() {
    super.initState();
    _probe = ref.read(outboundIpProbeProvider.notifier)..watch(routedOutbound);
  }

  @override
  void dispose() {
    _probe.unwatch(routedOutbound);
    super.dispose();
  }

  void _refresh(String? ip) {
    _probe.refresh(const [routedOutbound]);
    if (ip != null && ref.read(ipRiskProvider(ip)).hasError) {
      ref.invalidate(ipRiskProvider(ip));
    }
  }

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    final isStart = ref.watch(isStartProvider);
    final suspended = isStart && ref.watch(suspendProvider);
    final rootAccess =
        rsFeature && (ref.watch(rootAccessProvider).value ?? false);
    final entry = ref.watch(
      outboundIpProbeProvider.select((state) => state.entryOf(routedOutbound)),
    );
    final ipInfo = entry.value;
    final phase = entry.phase;
    final failed = phase == ProbePhase.failed && ipInfo == null;
    final qualityState = ipInfo == null
        ? null
        : ref.watch(ipRiskProvider(ipInfo.ip));
    final quality = qualityState?.value;
    final qualityLoading =
        qualityState != null && quality == null && qualityState.isLoading;
    final loading = ipInfo == null ? !failed : qualityLoading;
    final metrics = _OutboundMetrics.of(density);
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final (chipLabel, chipTone) = suspended
        ? (appLocalizations.suspended, DashboardChipTone.warn)
        : isStart
        ? (appLocalizations.running, DashboardChipTone.ok)
        : (appLocalizations.notRunning, DashboardChipTone.idle);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: rootAccess ? 1 : 0),
      duration: context.motionDuration(commonDuration),
      builder: (context, root, child) => DashboardCard(
        padding: EdgeInsets.zero,
        semanticLabel: rootAccess
            ? '${appLocalizations.status} ${appLocalizations.root}'
            : appLocalizations.status,
        side: root == 0
            ? BorderSide.none
            : BorderSide(
                color: context.colorScheme.primary.withValues(alpha: root),
                width: 1.5,
              ),
        child: child!,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: ShapeBorderClipper(
                shape: AppShape.all(dashboardCardRadius(density)),
                textDirection: Directionality.of(context),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  PositionedDirectional(
                    end: metrics.decorationEnd,
                    bottom: metrics.decorationBottom,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: isStart ? 1 : 0),
                      duration: context.motionDuration(_morphDuration),
                      curve: Curves.easeOutBack,
                      builder: (_, progress, _) => Transform.rotate(
                        angle: _decorationTurn * progress,
                        child: Transform.scale(
                          scale: 1 + _decorationGrowth * progress,
                          child: ShapeBadge(
                            shape: MaterialShapes.cookie12Sided,
                            color: Color.lerp(
                              colors.tone,
                              Color.alphaBlend(
                                colorScheme.primary.withValues(alpha: 0.1),
                                colors.card,
                              ),
                              progress.clamp(0, 1),
                            )!,
                            size: metrics.decorationSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: metrics.padding,
            child: Row(
              spacing: metrics.gap,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DashboardCardHeader(
                        glyph: AppGlyphs.status,
                        title: appLocalizations.status,
                        leading: [
                          DashboardChip(
                            label: chipLabel,
                            tone: chipTone,
                            dot: isStart,
                          ),
                        ],
                      ),
                      if (density.isDesktop)
                        const Spacer()
                      else
                        SizedBox(height: metrics.ipTop),
                      _ExitRow(
                        info: ipInfo,
                        quality: quality,
                        failed: failed,
                        loading: loading,
                        checking: phase == ProbePhase.probing || qualityLoading,
                        onRefresh: () => _refresh(ipInfo?.ip),
                        active: isStart && !suspended,
                        metrics: metrics,
                      ),
                      if (density.isDesktop)
                        const Spacer()
                      else
                        const SizedBox(height: 16),
                      _Cells(
                        quality: quality,
                        loading: loading,
                        active: isStart && !suspended,
                        gap: metrics.cellGap,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: metrics.buttonSlot,
                  child: Center(
                    child: _StartToggle(
                      size: metrics.buttonSize,
                      enabled: hasProfile,
                      running: isStart,
                      suspended: suspended,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutboundMetrics {
  const _OutboundMetrics({
    required this.padding,
    required this.gap,
    required this.ipTop,
    required this.cellGap,
    required this.badgeSize,
    required this.ip,
    required this.buttonSize,
    required this.buttonSlot,
    required this.decorationSize,
    required this.decorationEnd,
  });

  factory _OutboundMetrics.of(DashboardDensity density) => switch (density) {
    DashboardDensity.standard => _OutboundMetrics(
      padding: dashboardCardPadding(density),
      gap: 16,
      ipTop: 10,
      cellGap: 28,
      badgeSize: 48,
      ip: AppTextStyle.title1,
      buttonSize: 104,
      buttonSlot: 120,
      decorationSize: 268,
      decorationEnd: -52,
    ),
    DashboardDensity.compact => _OutboundMetrics(
      padding: dashboardCardPadding(density),
      gap: 16,
      ipTop: 8,
      cellGap: 22,
      badgeSize: 40,
      ip: AppTextStyle.title2,
      buttonSize: 84,
      buttonSlot: 100,
      decorationSize: 232,
      decorationEnd: -46,
    ),
    DashboardDensity.mobile => const _OutboundMetrics(
      padding: EdgeInsetsDirectional.fromSTEB(20, 18, 16, 18),
      gap: 10,
      ipTop: 12,
      cellGap: 18,
      badgeSize: 48,
      ip: AppTextStyle.title2,
      buttonSize: 88,
      buttonSlot: 88,
      decorationSize: 216,
      decorationEnd: -48,
    ),
  };

  final EdgeInsetsGeometry padding;
  final double gap;
  final double ipTop;
  final double cellGap;
  final double badgeSize;
  final AppTextStyle ip;
  final double buttonSize;
  final double buttonSlot;
  final double decorationSize;
  final double decorationEnd;

  /// Places the unscaled flower box so that when expanded by [_decorationGrowth],
  /// its lowest lobe rests [_decorationBottomGap] above the card's bottom edge.
  double get decorationBottom =>
      _decorationBottomGap + decorationSize * _decorationGrowth / 2;
}

class _ExitRow extends StatelessWidget {
  const _ExitRow({
    required this.info,
    required this.quality,
    required this.failed,
    required this.loading,
    required this.checking,
    required this.onRefresh,
    required this.active,
    required this.metrics,
  });

  final IpInfo? info;
  final IpRisk? quality;
  final bool failed;
  final bool loading;
  final bool checking;
  final VoidCallback onRefresh;
  final bool active;
  final _OutboundMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final style = DashboardText.figure(
      context,
      metrics.ip,
      color: active ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
    );
    final info = this.info;
    final appLocalizations = context.appLocalizations;
    final Widget ip = info != null
        ? Tooltip(
            message: appLocalizations.details(appLocalizations.outboundIp),
            child: FocusRing(
              shape: AppShape.xs,
              standsOff: true,
              child: PressRegion(
                onTap: () => showIpQualitySheet(context, ip: info.ip),
                shape: AppShape.xs,
                overlay: PressRegion.focusOverlay,
                child: _IpText(ip: info.ip, style: style),
              ),
            ),
          )
        : failed
        ? Text(
            appLocalizations.serviceFailed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: colorScheme.error),
          )
        : SkeletonText(width: 140, style: style);
    final ipHeight = MediaQuery.textScalerOf(
      context,
    ).scale((style.fontSize ?? metrics.ip.size) * (style.height ?? 1.15));
    final effectiveCountryCode =
        (quality?.countryCode.trim().isNotEmpty ?? false)
        ? quality!.countryCode
        : info?.countryCode;
    return Row(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CountryBadge(
          countryCode: effectiveCountryCode,
          size: metrics.badgeSize,
          active: active,
          checking: checking,
          onRefresh: onRefresh,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: ipHeight,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ip,
                ),
              ),
              const SizedBox(height: 3),
              _IpLocationSubText(
                quality: quality,
                countryCode: effectiveCountryCode,
                loading: loading,
                active: active,
                onTap: info != null
                    ? () => showIpQualitySheet(context, ip: info.ip)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IpText extends ConsumerWidget {
  const _IpText({required this.ip, required this.style});

  final String ip;
  final TextStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideIp = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    if (!hideIp) {
      return DashboardFitText(ip, style: style);
    }
    return DashboardFitText(
      _ipMask,
      style: style.copyWith(
        fontFamily: FontFamily.mapleMono.value,
        color: context.colorScheme.success,
      ),
    );
  }
}

class _IpLocationSubText extends StatelessWidget {
  const _IpLocationSubText({
    required this.quality,
    required this.countryCode,
    required this.loading,
    required this.active,
    this.onTap,
  });

  final IpRisk? quality;
  final String? countryCode;
  final bool loading;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDesktop = DashboardDensityScope.of(context).isDesktop;
    final style = AppTextStyle.footnote
        .of(context, emphasized: true)
        .copyWith(
          fontSize: isDesktop ? 13 : 12.5,
          height: 1.2,
          color: active
              ? context.colorScheme.onSurfaceVariant
              : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        );
    final subHeight = MediaQuery.textScalerOf(context).scale(18.0);
    return SizedBox(
      height: subHeight,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _buildContent(context, style),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TextStyle style) {
    if (loading) {
      return SkeletonText(width: 80, style: style);
    }
    final riskCountry = quality?.country.trim();
    final rawCode = (quality?.countryCode.trim().isNotEmpty ?? false)
        ? quality!.countryCode.trim()
        : countryCode?.trim();
    final fallbackCode = (rawCode != null && rawCode.isNotEmpty)
        ? rawCode.toUpperCase()
        : null;
    final localized = localizedCountryName(
      rawCode,
      Localizations.maybeLocaleOf(context),
    );
    final display = (localized != null && localized.isNotEmpty)
        ? localized
        : (riskCountry != null && riskCountry.isNotEmpty)
        ? riskCountry
        : (quality?.placeLabel?.isNotEmpty ?? false)
        ? quality!.placeLabel
        : fallbackCode;
    if (display == null || display.isEmpty) {
      return Text('\u2014', maxLines: 1, style: style);
    }
    final foreground = active
        ? context.colorScheme.onSurface
        : context.colorScheme.onSurfaceVariant;
    final row = _LocationLabelRow(
      text: display,
      style: style.copyWith(color: foreground),
      iconSize: 13,
    );
    final interactive = onTap == null
        ? row
        : FocusRing(
            shape: AppShape.xs,
            standsOff: true,
            child: PressRegion(
              onTap: onTap,
              shape: AppShape.xs,
              overlay: PressRegion.focusOverlay,
              child: row,
            ),
          );
    final tooltip = quality?.fullLocationLabel;
    if (tooltip == null || tooltip.isEmpty) return interactive;
    return Tooltip(message: tooltip, child: interactive);
  }
}

class _LocationLabelRow extends StatefulWidget {
  const _LocationLabelRow({
    required this.text,
    required this.style,
    required this.iconSize,
  });

  final String text;
  final TextStyle style;
  final double iconSize;

  @override
  State<_LocationLabelRow> createState() => _LocationLabelRowState();
}

class _LocationLabelRowState extends State<_LocationLabelRow> {
  (String, TextStyle, double, TextDirection, Locale?)? _inkKey;
  Future<TextInk?>? _measurement;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final measureStyle = widget.style.copyWith(color: const Color(0xFF000000));
    final key = (
      widget.text,
      measureStyle,
      scaler.scale(measureStyle.fontSize ?? 13),
      direction,
      locale,
    );

    if (_inkKey != key) {
      _inkKey = key;
      final capitals = widget.text.runes
          .map(String.fromCharCode)
          .where(
            (letter) =>
                letter == letter.toUpperCase() &&
                letter != letter.toLowerCase(),
          )
          .join();
      _measurement = measureTextInk(
        capitals.isEmpty ? widget.text : capitals,
        measureStyle,
        scaler,
        textDirection: direction,
        locale: locale,
      );
    }

    final pin = GlyphIcon(
      AppGlyphs.location,
      size: widget.iconSize,
      color: widget.style.color,
    );
    final label = Text(
      widget.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
    return FutureBuilder<TextInk?>(
      key: ValueKey(key),
      future: _measurement,
      builder: (context, snapshot) {
        final ink = snapshot.data;
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 5,
          crossAxisAlignment: ink == null
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (ink == null)
              pin
            else
              BaselineAt(
                baseline:
                    widget.iconSize / 2 + (ink.ascent - ink.descent) / 2,
                child: pin,
              ),
            Flexible(child: label),
          ],
        );
      },
    );
  }
}

const _spinPeriod = Duration(milliseconds: 1500);

final _badgeMorph = Morph(MaterialShapes.circle, MaterialShapes.clover4Leaf);

Path _badgeMorphPath(double progress) => _badgeMorph.toPath(progress: progress);

/// The exit's circular flag framed by a curated 5-tone halo ring that smoothly
/// morphs into a spinning 4-leaf clover while checking, mirroring [_StartToggle].
class _CountryBadge extends ConsumerStatefulWidget {
  const _CountryBadge({
    required this.countryCode,
    required this.size,
    required this.active,
    required this.checking,
    required this.onRefresh,
  });

  final String? countryCode;
  final double size;
  final bool active;
  final bool checking;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_CountryBadge> createState() => _CountryBadgeState();
}

class _CountryBadgeState extends ConsumerState<_CountryBadge>
    with TickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(
    vsync: this,
    duration: _spinPeriod,
  );
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: _morphDuration,
    value: _targetMorph,
  );
  late final CurvedAnimation _morphCurve = CurvedAnimation(
    parent: _morph,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  var _hovered = false;
  var _focused = false;
  var _initialized = false;
  String? _displayedFlagAsset;
  CountryFlagTone _displayedTone = CountryFlagTone.grey;

  bool get _showsFlag =>
      !widget.checking && countryFlagAsset(widget.countryCode) != null;

  double get _targetMorph => _showsFlag ? 0 : 1;

  @override
  void initState() {
    super.initState();
    _syncFlagCache();
  }

  void _syncFlagCache() {
    final asset = countryFlagAsset(widget.countryCode);
    if (asset != null) {
      _displayedFlagAsset = asset;
      _displayedTone = countryFlagTone(widget.countryCode);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final first = !_initialized;
    _initialized = true;
    _syncAnimations(initial: first);
  }

  @override
  void didUpdateWidget(_CountryBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countryCode != widget.countryCode) {
      _syncFlagCache();
    }
    if (oldWidget.checking != widget.checking ||
        oldWidget.countryCode != widget.countryCode) {
      _syncAnimations();
    }
  }

  @override
  void dispose() {
    _morphCurve.dispose();
    _morph.dispose();
    _turns.dispose();
    super.dispose();
  }

  void _syncAnimations({bool initial = false}) {
    if (context.disableAnimations) {
      _turns.value = 0;
      _morph.value = _targetMorph;
      return;
    }
    if (widget.checking) {
      _turns.repeat();
    } else {
      // A clover looks the same every quarter turn, so it stops on the next.
      final rest = (_turns.value * 4).ceil() / 4;
      if (rest == _turns.value) {
        _turns.stop();
      } else {
        _turns.animateTo(rest, duration: _spinPeriod * (rest - _turns.value));
      }
    }
    if (initial) {
      _morph.value = _targetMorph;
    } else if (_showsFlag) {
      _morph.reverse();
    } else {
      _morph.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final foreground = widget.active
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;
    final enabled = !widget.checking;
    final size = widget.size;
    final code = widget.countryCode;
    final tooltip = context.appLocalizations.retry;
    final cloverColor = Color.alphaBlend(
      foreground.withValues(alpha: enabled && _hovered ? 0.08 : 0),
      DashboardColors.of(context).tone2,
    );
    final themeSpec = ref.watch(
      themeSettingProvider.select(
        (state) => (
          primaryColor: state.primaryColor,
          colorStyle: state.colorStyle,
        ),
      ),
    );
    final dynamicSeed = ref.watch(
      dynamicColorProvider.select(
        (seeds) => seeds.seedOf(colorScheme.brightness),
      ),
    );
    final seedColor = themeSpec.primaryColor != null
        ? Color(themeSpec.primaryColor!)
        : dynamicSeed;
    final colorStyle = themeSpec.colorStyle;
    final ringPalette = countryFlagRingColors(
      _displayedTone,
      colorScheme,
      colorStyle,
      seedColor: seedColor,
    );
    final flagOverlay = countryFlagOverlayStyle(colorScheme, colorStyle);
    final ringColor = Color.alphaBlend(
      foreground.withValues(alpha: enabled && _hovered ? 0.08 : 0),
      ringPalette.ring,
    );
    final ringPadding = size >= 44 ? 2.8 : 2.3;
    final flagSize = size - ringPadding * 2;
    final flagAsset = _displayedFlagAsset;
    final cloverChild = code == null || code.isEmpty
        ? GlyphIcon(
            AppGlyphs.proxies,
            size: size * 0.42,
            color: foreground,
          )
        : Text(
            code.toUpperCase(),
            maxLines: 1,
            style: AppTextStyle.footnote
                .of(context, emphasized: true)
                .copyWith(
                  color: foreground,
                  letterSpacing: 0.04 * AppTextStyle.footnote.size,
                ),
          );

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: PressRegion(
          onTap: enabled ? widget.onRefresh : null,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          child: ElasticPress(
            enabled: enabled,
            child: AnimatedBuilder(
              animation: Listenable.merge([_turns, _morphCurve]),
              builder: (_, _) {
                final morph = _morphCurve.value;
                final t = morph.clamp(0.0, 1.0);
                final fill = Color.lerp(ringColor, cloverColor, t)!;
                final glowAlpha = ringPalette.glow.a * (1 - t);
                final glow = glowAlpha > 0.005
                    ? ringPalette.glow.withValues(alpha: glowAlpha)
                    : const Color(0x00000000);
                final innerGlowAlpha = ringPalette.innerGlow.a * (1 - t);
                final innerGlow = innerGlowAlpha > 0.005
                    ? ringPalette.innerGlow.withValues(alpha: innerGlowAlpha)
                    : const Color(0x00000000);
                final flagOpacity = flagAsset == null
                    ? 0.0
                    : (1 - t * 1.45).clamp(0.0, 1.0);
                final cloverOpacity = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
                final rotation = _turns.value * 2 * math.pi;

                return CountryBadgeShape(
                  morphProgress: morph,
                  rotation: rotation,
                  color: fill,
                  glow: glow,
                  innerGlow: innerGlow,
                  size: size,
                  ring: _focused ? focusRingSide(colorScheme) : null,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (flagAsset != null && flagOpacity > 0)
                        Opacity(
                          opacity: flagOpacity,
                          child: Transform.scale(
                            scale: 1 - 0.24 * t,
                            child: Padding(
                              padding: EdgeInsets.all(ringPadding),
                              child: ClipOval(
                                child: SizedBox.square(
                                  dimension: flagSize,
                                  child: CustomPaint(
                                    foregroundPainter:
                                        flagOverlay.tintVeil.a > 0
                                        ? _FlagTintPainter(
                                            tintVeil: flagOverlay.tintVeil,
                                          )
                                        : null,
                                    child: Transform.scale(
                                      scale: 1.02,
                                      child: ColorFiltered(
                                        colorFilter: ColorFilter.matrix(
                                          flagOverlay.colorMatrix,
                                        ),
                                        child: SvgPicture.asset(
                                          flagAsset,
                                          width: flagSize,
                                          height: flagSize,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (cloverOpacity > 0)
                        Opacity(
                          opacity: cloverOpacity,
                          child: Transform.scale(
                            scale: 0.82 + 0.18 * cloverOpacity,
                            child: cloverChild,
                          ),
                        ),
                    ],
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

/// Paints the circular-flag-to-clover4Leaf morph for [_CountryBadge].
class CountryBadgeShape extends StatelessWidget {
  const CountryBadgeShape({
    super.key,
    required this.morphProgress,
    required this.rotation,
    required this.color,
    required this.glow,
    this.innerGlow = const Color(0x00000000),
    required this.size,
    this.ring,
    this.child,
  });

  final double morphProgress;
  final double rotation;
  final Color color;
  final Color glow;
  final Color innerGlow;
  final double size;
  final BorderSide? ring;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CountryBadgeMorphPainter(
        morphProgress: morphProgress,
        rotation: rotation,
        color: color,
        glow: glow,
        innerGlow: innerGlow,
        ring: ring,
      ),
      child: SizedBox.square(
        dimension: size,
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _FlagTintPainter extends CustomPainter {
  const _FlagTintPainter({required this.tintVeil});

  final Color tintVeil;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = tintVeil
        ..blendMode = BlendMode.color,
    );
  }

  @override
  bool shouldRepaint(_FlagTintPainter oldDelegate) =>
      oldDelegate.tintVeil != tintVeil;
}

class _CountryBadgeMorphPainter extends CustomPainter {
  const _CountryBadgeMorphPainter({
    required this.morphProgress,
    required this.rotation,
    required this.color,
    required this.glow,
    required this.innerGlow,
    required this.ring,
  });

  static const _outerGlowBlur = 15.0;
  static const _outerGlowSpread = 1.0;
  static const _innerGlowBlur = 4.0;

  final double morphProgress;
  final double rotation;
  final Color color;
  final Color glow;
  final Color innerGlow;
  final BorderSide? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _badgeMorphPath(morphProgress);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(rotation)
      ..scale(size.width, size.height)
      ..translate(-0.5, -0.5);
    if (glow.a > 0) {
      final spreadScale = 1 + _outerGlowSpread * 2 / size.width;
      canvas
        ..save()
        ..translate(0.5, 0.5)
        ..scale(spreadScale)
        ..translate(-0.5, -0.5)
        ..drawPath(
          path,
          Paint()
            ..color = glow
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              _outerGlowBlur / 2 / size.width / spreadScale,
            ),
        )
        ..restore();
    }
    if (innerGlow.a > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = innerGlow
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            _innerGlowBlur / 2 / size.width,
          ),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
    if (ring case final ring?) {
      strokeUnitShape(canvas, path, size.width, ring);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CountryBadgeMorphPainter oldDelegate) =>
      oldDelegate.morphProgress != morphProgress ||
      oldDelegate.rotation != rotation ||
      oldDelegate.color != color ||
      oldDelegate.glow != glow ||
      oldDelegate.innerGlow != innerGlow ||
      oldDelegate.ring != ring;
}

class _Cells extends StatelessWidget {
  const _Cells({
    required this.quality,
    required this.loading,
    required this.active,
    required this.gap,
  });

  final IpRisk? quality;
  final bool loading;
  final bool active;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final risk = quality;
    final Widget scoreValue = risk != null
        ? _FraudScoreValue(risk: risk)
        : loading
        ? SkeletonText(width: 56, style: _cellStyle(context))
        : const _Placeholder();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RunTimeCell(active: active),
        SizedBox(width: gap),
        Expanded(
          child: _Cell(label: appLocalizations.ipRiskScore, value: scoreValue),
        ),
      ],
    );
  }
}

class _FraudScoreValue extends StatelessWidget {
  const _FraudScoreValue({required this.risk});

  final IpRisk risk;

  @override
  Widget build(BuildContext context) {
    final scoreColor = riskScoreColor(risk.displayScore);
    final scoreStyle = _cellStyle(context);
    final colorScheme = context.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final denominatorStyle = scoreStyle.copyWith(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      height: 1.0,
      letterSpacing: 0,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
    );
    final pillTextStyle = AppTextStyle.caption1
        .of(context, emphasized: true)
        .toTabular
        .copyWith(color: scoreColor);
    final pillHeight = MediaQuery.textScalerOf(context).scale(22.0);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${risk.displayScore}',
                  style: scoreStyle.copyWith(color: scoreColor),
                ),
                TextSpan(text: ' / 100', style: denominatorStyle),
              ],
            ),
            maxLines: 1,
            style: scoreStyle,
          ),
          const SizedBox(width: 8),
          Container(
            height: pillHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: ShapeDecoration(
              shape: AppShape.full.copyWith(
                side: BorderSide(
                  color: scoreColor.withValues(alpha: isDark ? 0.42 : 0.36),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  risk.levelLabel(context),
                  maxLines: 1,
                  style: pillTextStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final cellHeight = MediaQuery.textScalerOf(context).scale(22.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.label(context),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: cellHeight,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: value,
          ),
        ),
      ],
    );
  }
}

TextStyle _cellStyle(BuildContext context) {
  final isDesktop = DashboardDensityScope.of(context).isDesktop;
  final size = isDesktop ? 16.5 : 15.5;
  return AppTextStyle.callout
      .of(context, emphasized: true)
      .toTabular
      .copyWith(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 22 / size,
        letterSpacing: -0.01 * size,
      );
}

class _CellText extends StatelessWidget {
  const _CellText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _cellStyle(context),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Text('—', maxLines: 1, style: _cellStyle(context));
  }
}

double _measureTextWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

double _runTimeSlotWidth(BuildContext context, int hourDigits) {
  final style = _cellStyle(context);
  final labelStyle = DashboardText.label(context);
  final count = math.max(2, hourDigits);
  final template8 = '${'8' * count}:88:88';
  final template0 = '${'0' * count}:00:00';
  final template4 = '${'4' * count}:44:44';
  final template9 = '${'9' * count}:99:99';
  final w8 = _measureTextWidth(context, template8, style);
  final w0 = _measureTextWidth(context, template0, style);
  final w4 = _measureTextWidth(context, template4, style);
  final w9 = _measureTextWidth(context, template9, style);
  final valueWidth = math.max(math.max(w8, w0), math.max(w4, w9));
  final labelWidth = _measureTextWidth(
    context,
    context.appLocalizations.runTime,
    labelStyle,
  );
  return math.max(valueWidth, labelWidth) + 1.0;
}

class _RunTimeCell extends ConsumerWidget {
  const _RunTimeCell({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final String timeText;
    final int hourDigits;
    if (active) {
      timeText = getTimeText(ref.watch(runTimeProvider));
      final colon = timeText.indexOf(':');
      hourDigits = colon == -1 ? 2 : math.max(2, colon);
    } else {
      timeText = '00:00:00';
      hourDigits = 2;
    }
    final slotWidth = _runTimeSlotWidth(context, hourDigits);

    return SizedBox(
      width: slotWidth,
      child: _Cell(label: appLocalizations.runTime, value: _CellText(timeText)),
    );
  }
}

const _morphDuration = Duration(milliseconds: 450);
const _stateDuration = Duration(milliseconds: 150);

final _startMorph = Morph(MaterialShapes.circle, MaterialShapes.cookie9Sided);

Path _morphPath(double progress) => _startMorph.toPath(progress: progress);

double _morphTurn(double progress) => progress * 2 * math.pi / 9;

/// A circle with a play glyph while stopped that grows the cookie-9 of a
/// running tunnel, the way the M3 Expressive loader morphs between shapes.
class _StartToggle extends ConsumerStatefulWidget {
  const _StartToggle({
    required this.size,
    required this.enabled,
    required this.running,
    required this.suspended,
  });

  final double size;
  final bool enabled;
  final bool running;
  final bool suspended;

  @override
  ConsumerState<_StartToggle> createState() => _StartToggleState();
}

class _StartToggleState extends ConsumerState<_StartToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _morphDuration,
    value: widget.running ? 1 : 0,
  );
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  var _hovered = false;
  var _pressed = false;
  var _focused = false;

  /// The M3 state layer, painted inside the shape: the card's decoration
  /// covers the button, so ink on the card would never show.
  double get _overlay => !widget.enabled
      ? 0
      : _focused
      ? 0.1
      : _hovered
      ? 0.08
      : 0;

  @override
  void didUpdateWidget(_StartToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running != widget.running) {
      widget.running ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    final glass = LiquidGlassScope.of(context);
    final size = widget.size;
    final enabled = widget.enabled;
    final fill = enabled
        ? colorScheme.primary
        : DashboardColors.of(context).tone2;
    final ink = enabled ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
    final tooltip = widget.suspended
        ? appLocalizations.suspended
        : widget.running
        ? appLocalizations.stop
        : appLocalizations.start;
    final stateDuration = context.motionDuration(_stateDuration);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: PressRegion(
          onTap: enabled ? _toggle : null,
          onHover: (value) => setState(() => _hovered = value),
          onPressedChanged: (value) => setState(() => _pressed = value),
          onFocusChange: (value) => setState(() => _focused = value),
          child: ElasticPress(
            enabled: enabled,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _overlay),
              duration: stateDuration,
              builder: (_, overlay, child) => AnimatedBuilder(
                animation: _progress,
                builder: (_, child) {
                  final progress = _progress.value;
                  final color = Color.alphaBlend(
                    ink.withValues(alpha: overlay),
                    fill,
                  );
                  return CustomPaint(
                    painter: _MorphPainter(
                      progress: progress,
                      color: glass ? null : color,
                      shadow: enabled
                          ? colorScheme.primary.withValues(alpha: 0.3)
                          : Colors.transparent,
                      ring: _focused
                          ? focusRingSide(colorScheme, standsOff: true)
                          : null,
                    ),
                    child: glass
                        ? LiquidGlass(
                            style: LiquidGlassStyle.tinted(colorScheme, color),
                            clipper: _MorphClipper(progress),
                            pressed: _pressed,
                            child: child,
                          )
                        : child,
                  );
                },
                child: child,
              ),
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: widget.suspended
                      ? GlyphIcon(
                          AppGlyphs.wifiOff,
                          size: size * 0.34,
                          color: ink,
                          fill: 1,
                        )
                      : TweenAnimationBuilder<double>(
                          tween: Tween(end: widget.running ? 1 : 0),
                          duration: _morphDuration,
                          curve: Curves.easeOutBack,
                          builder: (_, progress, _) => GlyphIcon(
                            AppGlyphs.playPause(progress),
                            size: size * 0.34,
                            color: ink,
                            fill: 1,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fills the morph, or with no [color] leaves its inside to glass and casts
/// [shadow] only outside it, as one under glass would show through.
class _MorphPainter extends CustomPainter {
  const _MorphPainter({
    required this.progress,
    required this.color,
    required this.shadow,
    required this.ring,
  });

  static const _shadowOffset = Offset(0, 6);
  static const _shadowBlur = 14.0;

  final double progress;
  final Color? color;
  final Color shadow;
  final BorderSide? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _morphPath(progress);
    final color = this.color;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(_morphTurn(progress))
      ..scale(size.width, size.height)
      ..translate(-0.5, -0.5);
    if (shadow.a > 0) {
      canvas.save();
      if (color == null) {
        canvas.clipPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(const Rect.fromLTRB(-1, -1, 2, 2))
            ..addPath(path, Offset.zero),
        );
      }
      canvas
        ..translate(
          _shadowOffset.dx / size.width,
          _shadowOffset.dy / size.height,
        )
        ..drawPath(
          path,
          Paint()
            ..color = shadow
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              _shadowBlur / 2 / size.width,
            ),
        )
        ..restore();
    }
    if (color != null) {
      canvas.drawPath(path, Paint()..color = color);
    }
    if (ring case final ring?) {
      strokeUnitShape(canvas, path, size.width, ring);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MorphPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.shadow != shadow ||
      oldDelegate.ring != ring;
}

class _MorphClipper extends CustomClipper<Path> {
  const _MorphClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final transform =
        Matrix4.translationValues(size.width / 2, size.height / 2, 0)
          ..rotateZ(_morphTurn(progress))
          ..scaleByDouble(size.width, size.height, 1, 1)
          ..translateByDouble(-0.5, -0.5, 0, 1);
    return _morphPath(progress).transform(transform.storage);
  }

  @override
  bool shouldReclip(_MorphClipper oldClipper) =>
      oldClipper.progress != progress;
}
