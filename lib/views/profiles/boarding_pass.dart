import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/vertical_ticket_perforation.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/dashboard/widgets/profile_detail.dart';
import 'package:fl_clash/views/dashboard/widgets/profiles.dart';
import 'package:fl_clash/views/profiles/custom/custom.dart';
import 'package:fl_clash/views/profiles/extend/extend.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edit.dart';
import 'preview.dart';
import 'profile_icon.dart';

typedef ProfileUsageData = ({int used, int total, int remaining, double share});

ProfileUsageData? profileUsageOf(Profile profile) {
  if (profile.type != ProfileType.url) {
    return null;
  }
  final info = profile.subscriptionInfo;
  if (info == null || info.total <= 0) {
    return null;
  }
  final used = math.max(0, info.upload + info.download);
  final remaining = math.max(0, info.total - used);
  return (
    used: used,
    total: info.total,
    remaining: remaining,
    share: (used / info.total).clamp(0.0, 1.0).toDouble(),
  );
}

DateTime? profileExpireDateOf(Profile profile) =>
    profile.type == ProfileType.url ? profile.subscriptionInfo?.expireDate : null;

bool profileIsExpired(Profile profile) {
  final expire = profileExpireDateOf(profile);
  return expire != null && expire.isBeforeNow;
}

int profileDaysLeft(DateTime expire) =>
    math.max(0, expire.difference(DateTime.now()).inDays);

String profileSubtitleText(BuildContext context, Profile profile) {
  final l = context.appLocalizations;
  final time = profile.lastUpdateDate?.getLastUpdateTimeDesc(
    context,
    compact: true,
  );
  final expire = profileExpireDateOf(profile);
  final lead = switch (profile.type) {
    ProfileType.url => switch (expire) {
      final date? when date.isBeforeNow => l.expired,
      final date? => l.profileDaysLeft(profileDaysLeft(date)),
      null => l.infiniteTime,
    },
    ProfileType.file || ProfileType.custom => l.lastEdited,
  };
  return time == null || time.isEmpty ? lead : '$lead · $time';
}

Future<void> handleDeleteProfile(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final profilesAction = ref.read(profilesActionProvider.notifier);
  final appLocalizations = context.appLocalizations;
  final users = await profilesAction.providerUsers(profile);
  final res = await dialogs.showMessage(
    title: appLocalizations.tip,
    message: TextSpan(
      text: users.isEmpty
          ? appLocalizations.deleteTip(appLocalizations.profile)
          : appLocalizations.providerInUse(
              profile.realLabel,
              users.map((item) => item.realLabel).join(', '),
            ),
    ),
    destructive: true,
    confirmText: appLocalizations.delete,
  );
  if (res != true) {
    return;
  }
  await profilesAction.deleteProfile(profile.id);
}

Future<void> handleSyncProfile(WidgetRef ref, Profile profile) async {
  if (profile.type != ProfileType.url) return;
  await globalState.loadingRun(() async {
    await ref
        .read(profilesActionProvider.notifier)
        .updateProfile(profile, showLoading: true);
  }, tag: LoadingTag.profiles);
}

void handleEditProfile(BuildContext context, Profile profile) {
  if (profile.type == ProfileType.custom) {
    BaseNavigator.push(context, CustomProfileView(profileId: profile.id));
  } else {
    showNestedExtend(
      context,
      builder: (context) => EditProfileView(profile: profile),
    );
  }
}

void handleExtendProfile(BuildContext context, Profile profile) {
  BaseNavigator.push(context, ExtendView(profileId: profile.id));
}

void handlePreviewProfile(BuildContext context, Profile profile) {
  unawaited(
    pushNestedPage<void>(context, PreviewProfileView(profile: profile)),
  );
}

Future<void> handleCopyProfileLink(BuildContext context, Profile profile) async {
  await Clipboard.setData(ClipboardData(text: profile.url));
  if (context.mounted) {
    dialogs.showBanner(
      context.appLocalizations.copySuccess,
      level: BannerLevel.success,
    );
  }
}

void handleShowProfileQrCode(BuildContext context, Profile profile) {
  dialogs.showQrCode(
    title: profile.realLabel,
    data: profile.url,
    message: context.appLocalizations.shareQrcodeTip,
  );
}

Future<void> handleExportProfileFile(
  BuildContext context,
  Profile profile,
) async {
  final appLocalizations = context.appLocalizations;
  final res = await globalState.safeRun<bool>(() async {
    final mFile = await profile.file;
    final value = await picker.saveFile(
      profile.exportFileName,
      mFile.readAsBytesSync(),
    );
    if (value == null) return false;
    return true;
  }, title: appLocalizations.tip);
  if (res == true && context.mounted) {
    dialogs.showBanner(
      appLocalizations.exportSuccess,
      level: BannerLevel.success,
    );
  }
}

List<PopupMenuItem> buildProfileMenuItems(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) {
  final appLocalizations = context.appLocalizations;
  final isUrl = profile.type == ProfileType.url;
  final isCustom = profile.type == ProfileType.custom;
  return [
    PopupMenuItem(
      glyph: AppGlyphs.edit,
      label: appLocalizations.edit,
      onPressed: () => handleEditProfile(context, profile),
    ),
    if (isCustom) ...[
      PopupMenuItem(
        glyph: AppGlyphs.textShort,
        label: appLocalizations.rename,
        onPressed: () => renameProfile(context, ref, profile),
      ),
      PopupMenuItem(
        glyph: AppGlyphs.photos,
        label: appLocalizations.customIcon,
        onPressed: () => openProfileIconPicker(context, ref, profile),
      ),
      PopupMenuItem(
        glyph: AppGlyphs.eye,
        label: appLocalizations.runtimeConfig,
        onPressed: () => handlePreviewProfile(context, profile),
      ),
    ] else ...[
      PopupMenuItem(
        glyph: AppGlyphs.puzzle,
        label: appLocalizations.extend,
        onPressed: () => handleExtendProfile(context, profile),
      ),
      if (isUrl)
        PopupMenuItem(
          glyph: AppGlyphs.sync,
          label: appLocalizations.sync,
          onPressed: () => handleSyncProfile(ref, profile),
        ),
      PopupMenuItem(
        glyph: AppGlyphs.photos,
        label: appLocalizations.customIcon,
        onPressed: () => openProfileIconPicker(context, ref, profile),
      ),
      PopupMenuItem(
        glyph: AppGlyphs.moreCircle,
        label: appLocalizations.more,
        subItems: [
          PopupMenuItem(
            glyph: AppGlyphs.eye,
            label: appLocalizations.runtimeConfig,
            onPressed: () => handlePreviewProfile(context, profile),
          ),
          if (isUrl)
            PopupMenuItem(
              glyph: AppGlyphs.copy,
              label: appLocalizations.copyLink,
              onPressed: () => handleCopyProfileLink(context, profile),
            ),
          if (isUrl)
            PopupMenuItem(
              glyph: AppGlyphs.qrCode,
              label: appLocalizations.qrcode,
              onPressed: () => handleShowProfileQrCode(context, profile),
            ),
          PopupMenuItem(
            glyph: AppGlyphs.export,
            label: appLocalizations.exportFile,
            onPressed: () => handleExportProfileFile(context, profile),
          ),
        ],
      ),
    ],
    PopupMenuItem(
      danger: true,
      glyph: AppGlyphs.delete,
      label: appLocalizations.delete,
      onPressed: () => handleDeleteProfile(context, ref, profile),
    ),
  ];
}

/// Active profile hero styled as a boarding pass ("飞机票"):
/// - Portrait (`!isWide`): vertical pass with top info + 2 circular actions
///   (primary + `⋯` PopupAnchor morph menu), horizontal perforated tear-line
///   with semicircular notches, and bottom traffic wavy bar or 3 stat tiles.
/// - Landscape (`isWide`): horizontal pass with left ticket body, vertical
///   perforated tear-line with top/bottom semicircular notches, and right stub
///   exposing all profile actions directly as a 2-row circular button matrix.
class ProfileBoardingPass extends ConsumerStatefulWidget {
  const ProfileBoardingPass({
    super.key,
    required this.profile,
    required this.isWide,
  });

  final Profile profile;
  final bool isWide;

  @override
  ConsumerState<ProfileBoardingPass> createState() =>
      _ProfileBoardingPassState();
}

class _ProfileBoardingPassState extends ConsumerState<ProfileBoardingPass>
    with ConfigCountsWatch<ProfileBoardingPass> {
  static const _nearlyUsedShare = 0.9;

  ProfileStats? _statsOf(List<ExternalProvider> providers) {
    final effectiveCounts =
        configCounts ?? cachedConfigCounts() ?? configCountsNotifier.value;
    return switch (effectiveCounts) {
      final counts? => profileStatsOf(counts, providers),
      null => providers.isNotEmpty
          ? (
              groups: 0,
              proxies: providers
                  .where((p) => p.type == 'Proxy')
                  .fold(0, (sum, p) => sum + p.count),
              rules: 0,
              providers: providers.length,
            )
          : null,
    };
  }

  Widget _buildTypeStamp(BuildContext context, Profile profile) {
    final colorScheme = context.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: DashboardColors.of(context).tone,
        shape: AppShape.all(AppCorner.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          profileTypeStamp(context, profile.type),
          maxLines: 1,
          style: AppTextStyle.caption2
              .of(context, emphasized: true)
              .copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(BuildContext context, Profile profile) {
    final colorScheme = context.colorScheme;
    final expired = profileIsExpired(profile);
    final subtitle = profileSubtitleText(context, profile);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ProfileIconBadge(
          profile: profile,
          size: 46,
          onTap: () => openProfileIconPicker(context, ref, profile),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: EmojiText(
                      profile.realLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.headline.of(
                        context,
                        emphasized: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildTypeStamp(context, profile),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: expired
                    ? AppTextStyle.footnote
                          .of(context, emphasized: true)
                          .copyWith(color: colorScheme.error)
                    : AppTextStyle.footnote.of(context).toLighter,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitActions(
    BuildContext context,
    Profile profile,
    bool isUpdating,
    List<PopupMenuItem> menuItems,
  ) {
    final l = context.appLocalizations;
    final Widget primaryButton = switch (profile.type) {
      ProfileType.url => _CircleIconButton(
        tooltip: l.sync,
        onPressed: isUpdating ? null : () => handleSyncProfile(ref, profile),
        child: isUpdating
            ? const ActivityIndicator(size: 16)
            : const GlyphIcon(AppGlyphs.sync, size: 18),
      ),
      ProfileType.file => _CircleIconButton(
        tooltip: l.edit,
        onPressed: () => handleEditProfile(context, profile),
        child: const GlyphIcon(AppGlyphs.edit, size: 18),
      ),
      ProfileType.custom => _CircleIconButton(
        tooltip: l.edit,
        onPressed: () => handleEditProfile(context, profile),
        child: const GlyphIcon(AppGlyphs.customize, size: 18),
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        primaryButton,
        PopupAnchor(
          targetBuilder: (open) => _CircleIconButton(
            tooltip: l.more,
            onPressed: isUpdating ? null : open,
            child: const GlyphIcon(AppGlyphs.more, size: 18),
          ),
          popupBuilder: (_) => PopupMenu(items: menuItems),
        ),
      ],
    );
  }

  Widget _buildUsageStub(
    BuildContext context,
    Profile profile,
    ProfileUsageData usage,
    ProfileStats? stats,
  ) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final expired = profileIsExpired(profile);
    final percentText = '${(usage.share * 100).round()}%';
    final trafficText =
        '${dashboardTraffic(usage.used)} / ${dashboardTraffic(usage.total)}';
    final percentStyle = DashboardText.figure(
      context,
      AppTextStyle.title3,
    ).copyWith(letterSpacing: 0);
    final unitStyle = DashboardText.unit(context, AppTextStyle.footnote);
    final trafficStyle = AppTextStyle.footnote
        .of(context)
        .toTabular
        .copyWith(color: colorScheme.onSurfaceVariant);
    final waveColor = expired
        ? colorScheme.error
        : usage.share >= _nearlyUsedShare
            ? colors.warn
            : colorScheme.primary;
    final leftFoot = expired
        ? l.expired
        : '${l.remainingShort} ${dashboardTraffic(usage.remaining)}';
    final expire = profileExpireDateOf(profile);
    final rightFoot = switch ((stats, expire)) {
      (final s?, _) when s.proxies > 0 || s.rules > 0 =>
        '${dashboardCount(s.proxies)} ${l.nodeCount} · ${dashboardCount(s.rules)} ${l.ruleCount}',
      (_, final date?) => date.show,
      _ => null,
    };

    final waveSpacing = widget.isWide ? 4.0 : 8.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: 12,
          children: [
            Flexible(
              fit: widget.isWide ? FlexFit.tight : FlexFit.loose,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: percentText, style: percentStyle),
                    TextSpan(text: ' ${l.usedShort}', style: unitStyle),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              trafficText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: trafficStyle,
            ),
          ],
        ),
        SizedBox(height: waveSpacing),
        SizedBox(
          height: 12,
          child: CustomPaint(
            painter: WavyProgressPainter(
              value: usage.share,
              active: waveColor,
              track: colors.tone2,
            ),
          ),
        ),
        SizedBox(height: waveSpacing),
        Row(
          spacing: 12,
          children: [
            Text(
              leftFoot,
              maxLines: 1,
              style: expired
                  ? AppTextStyle.caption1
                        .of(context, emphasized: true)
                        .copyWith(color: colorScheme.error)
                  : DashboardText.label(context),
            ),
            if (rightFoot != null)
              Expanded(
                child: Text(
                  rightFoot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: DashboardText.label(context),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsStub(
    BuildContext context,
    Profile profile,
    ProfileStats? stats,
    int? customGroupsCount,
  ) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final tileFill = DashboardColors.of(context).tone;
    final figureStyle = AppTextStyle.title3
        .of(context, emphasized: true)
        .toTabular
        .copyWith(color: colorScheme.onSurface, letterSpacing: 0, height: 1.0);
    final labelStyle = AppTextStyle.caption1
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant, height: 1.0);

    Widget valueWidget(int? value) {
      if (value != null) {
        return Text(dashboardCount(value), maxLines: 1, style: figureStyle);
      }
      if (configCountsFailed) {
        return Text('—', maxLines: 1, style: figureStyle);
      }
      return SkeletonText(width: 28, style: figureStyle);
    }

    Widget tile(int? value, String label) {
      return Expanded(
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: ShapeDecoration(
            color: tileFill,
            shape: AppShape.all(AppCorner.lg),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              valueWidget(value),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ],
          ),
        ),
      );
    }

    final isCustom = profile.type == ProfileType.custom;
    return Row(
      spacing: 8,
      children: [
        if (isCustom)
          tile(customGroupsCount ?? stats?.groups, l.proxyGroup)
        else
          tile(stats?.providers, l.providerCount),
        tile(stats?.proxies, l.nodeCount),
        tile(stats?.rules, l.ruleCount),
      ],
    );
  }

  ({List<_PillAction> pills, List<_StubAction> actions}) _landscapeStubPlan(
    BuildContext context,
    Profile profile,
    bool isUpdating,
  ) {
    final l = context.appLocalizations;
    final accent = profileTypeAccent(context, profile.type);
    return switch (profile.type) {
      ProfileType.url => (
        pills: [
          _PillAction(
            glyph: AppGlyphs.sync,
            label: l.sync,
            accent: accent,
            tinted: true,
            loading: isUpdating,
            onPressed: isUpdating
                ? null
                : () => handleSyncProfile(ref, profile),
          ),
          _PillAction(
            glyph: AppGlyphs.edit,
            label: l.edit,
            accent: accent,
            tinted: false,
            onPressed: () => handleEditProfile(context, profile),
          ),
          _PillAction(
            glyph: AppGlyphs.puzzle,
            label: l.extend,
            accent: accent,
            tinted: false,
            onPressed: () => handleExtendProfile(context, profile),
          ),
        ],
        actions: [
          _StubAction(
            glyph: AppGlyphs.photos,
            label: l.icon,
            onPressed: () => openProfileIconPicker(context, ref, profile),
          ),
          _StubAction(
            glyph: AppGlyphs.eye,
            label: l.preview,
            onPressed: () => handlePreviewProfile(context, profile),
          ),
          _StubAction(
            glyph: AppGlyphs.copy,
            label: l.copyLink,
            onPressed: () => handleCopyProfileLink(context, profile),
          ),
          _StubAction(
            glyph: AppGlyphs.qrCode,
            label: l.qrcode,
            onPressed: () => handleShowProfileQrCode(context, profile),
          ),
          _StubAction(
            glyph: AppGlyphs.export,
            label: l.exportFile,
            onPressed: () => handleExportProfileFile(context, profile),
          ),
          _StubAction(
            glyph: AppGlyphs.delete,
            label: l.delete,
            danger: true,
            onPressed: () => handleDeleteProfile(context, ref, profile),
          ),
        ],
      ),
      ProfileType.file => (
        pills: [
          _PillAction(
            glyph: AppGlyphs.edit,
            label: l.edit,
            accent: accent,
            tinted: true,
            onPressed: () => handleEditProfile(context, profile),
          ),
          _PillAction(
            glyph: AppGlyphs.puzzle,
            label: l.extend,
            accent: accent,
            tinted: false,
            onPressed: () => handleExtendProfile(context, profile),
          ),
        ],
        actions: [
          _StubAction(
            glyph: AppGlyphs.photos,
            label: l.icon,
            onPressed: () => openProfileIconPicker(context, ref, profile),
          ),
          _StubAction(
            glyph: AppGlyphs.eye,
            label: l.preview,
            onPressed: () => handlePreviewProfile(context, profile),
          ),
          _StubAction(
            glyph: AppGlyphs.export,
            label: l.exportFile,
            onPressed: () => handleExportProfileFile(context, profile),
          ),
          _StubAction(
            glyph: AppGlyphs.delete,
            label: l.delete,
            danger: true,
            onPressed: () => handleDeleteProfile(context, ref, profile),
          ),
        ],
      ),
      ProfileType.custom => (
        pills: [
          _PillAction(
            glyph: AppGlyphs.customize,
            label: l.edit,
            accent: accent,
            tinted: true,
            onPressed: () => handleEditProfile(context, profile),
          ),
        ],
        actions: [
          _StubAction(
            glyph: AppGlyphs.textShort,
            label: l.rename,
            onPressed: () => renameProfile(context, ref, profile),
          ),
          _StubAction(
            glyph: AppGlyphs.photos,
            label: l.icon,
            onPressed: () => openProfileIconPicker(context, ref, profile),
          ),
          _StubAction(
            glyph: AppGlyphs.eye,
            label: l.preview,
            onPressed: () => handlePreviewProfile(context, profile),
          ),
          _StubAction(
            glyph: AppGlyphs.delete,
            label: l.delete,
            danger: true,
            onPressed: () => handleDeleteProfile(context, ref, profile),
          ),
        ],
      ),
    };
  }

  Widget _buildLandscapeActionMatrix(
    BuildContext context,
    Profile profile,
    bool isUpdating,
  ) {
    final plan = _landscapeStubPlan(context, profile, isUpdating);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      spacing: profile.type == ProfileType.url ? 10 : 12,
      children: [
        Row(
          spacing: 8,
          children: [
            for (final pill in plan.pills)
              Expanded(child: _ActionPillButton(action: pill)),
          ],
        ),
        Row(
          children: [
            for (final action in plan.actions)
              Expanded(child: _LabeledCircleAction(action: action)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    watchConfigCounts();
    final profile = widget.profile;
    final isUpdating = ref.watch(isUpdatingProvider(profile.updatingKey));
    final providers = ref.watch(providersProvider);
    final customGroupsCount = profile.type == ProfileType.custom
        ? ref.watch(profileGroupsCountProvider(profile.id)).value
        : null;
    final stats = _statsOf(providers);
    final usage = profileUsageOf(profile);
    final colorScheme = context.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final cardColor = SurfaceLevel.card.colorOf(colorScheme);
    final pageColor = SurfaceLevel.page.colorOf(colorScheme);
    final dashColor = colorScheme.onSurface.withValues(
      alpha: isDark ? 0.14 : 0.11,
    );
    final menuItems = buildProfileMenuItems(context, ref, profile);

    final bodyMetrics = usage != null
        ? _buildUsageStub(context, profile, usage, stats)
        : _buildStatsStub(context, profile, stats, customGroupsCount);

    final Widget passContent;
    if (widget.isWide) {
      final isRemote = profile.type == ProfileType.url;
      passContent = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 12,
              child: Padding(
                padding: isRemote
                    ? const EdgeInsets.symmetric(horizontal: 20, vertical: 15)
                    : const EdgeInsets.fromLTRB(18, 18, 12, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: isRemote
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderInfo(context, profile),
                    SizedBox(height: isRemote ? 12 : 16),
                    bodyMetrics,
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 20,
              child: CustomPaint(
                painter: VerticalTicketPerforationPainter(
                  notchColor: pageColor,
                  dashColor: dashColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            Expanded(
              flex: 10,
              child: Padding(
                padding: isRemote
                    ? const EdgeInsets.fromLTRB(10, 12, 16, 12)
                    : const EdgeInsets.fromLTRB(10, 16, 16, 16),
                child: _buildLandscapeActionMatrix(
                  context,
                  profile,
                  isUpdating,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      passContent = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 10,
              children: [
                Expanded(child: _buildHeaderInfo(context, profile)),
                _buildPortraitActions(context, profile, isUpdating, menuItems),
              ],
            ),
          ),
          SizedBox(
            height: 18,
            child: CustomPaint(
              painter: _HorizontalPerforationPainter(
                notchColor: pageColor,
                dashColor: dashColor,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: bodyMetrics,
          ),
        ],
      );
    }

    return ContextMenuRegion(
      menuItems: isUpdating ? null : menuItems,
      child: Focus(
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: AppShape.all(AppCorner.xl)),
          child: ColoredBox(
            color: cardColor,
            child: SurfaceScope(
              level: SurfaceLevel.card,
              child: passContent,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillAction {
  const _PillAction({
    required this.glyph,
    required this.label,
    required this.accent,
    required this.tinted,
    required this.onPressed,
    this.loading = false,
  });

  final Glyph glyph;
  final String label;
  final Color accent;
  final bool tinted;
  final VoidCallback? onPressed;
  final bool loading;
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({required this.action});

  final _PillAction action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final fill = action.tinted
        ? action.accent.withValues(alpha: isDark ? 0.18 : 0.11)
        : DashboardColors.of(context).tone;
    final foreground = action.tinted ? action.accent : colorScheme.onSurface;
    return PressSurface(
      fill: fill,
      foreground: foreground,
      shape: AppShape.full,
      minimum: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onPressed: action.onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (action.loading)
            const ActivityIndicator(size: 15)
          else
            GlyphIcon(action.glyph, size: 16),
          Flexible(
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.footnote
                  .of(context, emphasized: true)
                  .copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.danger = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final fill = danger
        ? colorScheme.error.withValues(alpha: 0.12)
        : DashboardColors.of(context).tone;
    final foreground = danger ? colorScheme.error : colorScheme.onSurface;
    return Tooltip(
      message: tooltip,
      child: PressSurface(
        fill: fill,
        foreground: foreground,
        shape: AppShape.full,
        minimum: const BoxConstraints.tightFor(width: 34, height: 34),
        onPressed: onPressed,
        child: Center(child: child),
      ),
    );
  }
}

class _StubAction {
  const _StubAction({
    required this.glyph,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final Glyph glyph;
  final String label;
  final VoidCallback? onPressed;
  final bool danger;
}

class _LabeledCircleAction extends StatelessWidget {
  const _LabeledCircleAction({required this.action});

  final _StubAction action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final labelColor = action.danger
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleIconButton(
          tooltip: action.label,
          danger: action.danger,
          onPressed: action.onPressed,
          child: GlyphIcon(action.glyph, size: 17),
        ),
        const SizedBox(height: 5),
        Text(
          action.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyle.caption2.of(context).copyWith(color: labelColor),
        ),
      ],
    );
  }
}

class _HorizontalPerforationPainter extends CustomPainter {
  const _HorizontalPerforationPainter({
    required this.notchColor,
    required this.dashColor,
  });

  final Color notchColor;
  final Color dashColor;

  static const _notchRadius = 9.0;
  static const _dashWidth = 5.0;
  static const _dashGap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final dashPaint = Paint()
      ..color = dashColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    var x = _notchRadius + 6.0;
    final maxX = size.width - _notchRadius - 6.0;
    while (x < maxX) {
      final endX = math.min(x + _dashWidth, maxX);
      canvas.drawLine(Offset(x, y), Offset(endX, y), dashPaint);
      x += _dashWidth + _dashGap;
    }
    final notchPaint = Paint()..color = notchColor;
    canvas.drawCircle(Offset(0, y), _notchRadius, notchPaint);
    canvas.drawCircle(Offset(size.width, y), _notchRadius, notchPaint);
  }

  @override
  bool shouldRepaint(_HorizontalPerforationPainter oldDelegate) =>
      oldDelegate.notchColor != notchColor ||
      oldDelegate.dashColor != dashColor;
}
