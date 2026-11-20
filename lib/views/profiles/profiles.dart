import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add.dart';
import 'boarding_pass.dart';
import 'profile_icon.dart';

const _infoGap = 3.0;
const _cardVerticalPadding = 13.0;
const _wideBoardingPassBreakpoint = 720.0;

double get _profileItemHeight {
  final measure = globalState.measure;
  final textColumnHeight =
      measure.textHeight(AppTextStyle.headline) +
      _infoGap +
      measure.textHeight(AppTextStyle.footnote);
  return math.max(42.0, textColumnHeight) + 2 * _cardVerticalPadding;
}

class ProfilesView extends ConsumerStatefulWidget {
  const ProfilesView({super.key, this.picker = false});

  /// Clears the bar and opens at the top, for switching profiles from a sheet.
  final bool picker;

  @override
  ConsumerState<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends ConsumerState<ProfilesView> {
  bool _isUpdating = false;

  Future<void> _updateProfiles(List<Profile> profiles) async {
    if (_isUpdating == true) {
      return;
    }
    _isUpdating = true;
    final appLocalizations = context.appLocalizations;
    final profilesAction = ref.read(profilesActionProvider.notifier);
    final List<UpdatingMessage> messages = [];
    final updateProfiles = profiles.map<Future>((profile) async {
      if (profile.type != ProfileType.url) return;
      try {
        await profilesAction.updateProfile(profile, showLoading: true);
      } catch (e) {
        messages.add(
          UpdatingMessage(
            label: profile.realLabel,
            message: userFacingErrorMessage(e, appLocalizations),
          ),
        );
      }
    });
    await Future.wait(updateProfiles);
    dialogs.showFailures(messages);
    _isUpdating = false;
  }

  List<IconButtonData> _buildActions(List<Profile> profiles) {
    return profiles.isNotEmpty
        ? [
            IconButtonData(
              glyph: AppGlyphs.sync,
              onPressed: () {
                _updateProfiles(profiles);
              },
              tooltip: context.appLocalizations.update,
            ),
            IconButtonData(
              glyph: AppGlyphs.sort,
              onPressed: () {
                showNestedSheet(
                  context,
                  builder: (_) {
                    return ReorderableProfilesSheet(profiles: profiles);
                  },
                );
              },
              tooltip: context.appLocalizations.profilesSort,
            ),
          ]
        : [];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        final appLocalizations = context.appLocalizations;
        final isLoading = ref.watch(loadingProvider(LoadingTag.profiles));
        final state = ref.watch(profilesStateProvider);
        final spacing = cardSpacingOf(context, ref.watch(viewModeProvider));
        final picker = widget.picker;
        return Scaffold(
          isLoading: isLoading,
          title: appLocalizations.profiles,
          iconActions: picker ? const [] : _buildActions(state.profiles),
          actions: state.profiles.isEmpty || picker
              ? null
              : [
                  AddProfileMenu(
                    builder: (open) => IconButton(
                      tooltip: appLocalizations.addProfile,
                      onPressed: open,
                      icon: const GlyphIcon(AppGlyphs.addCircle),
                    ),
                  ),
                ],
          body: NullStatusSwitcher(
            isEmpty: state.profiles.isEmpty,
            nullStatus: NullStatus(
              label: appLocalizations.nullTip(appLocalizations.profiles),
              description: appLocalizations.nullProfileDesc,
              illustration: NullStatusIllustration.profile,
              action: AddProfileMenu(
                builder: (open) => TonalButton(
                  size: TonalButtonSize.bar,
                  glyph: AppGlyphs.addCircle,
                  label: appLocalizations.addProfile,
                  onPressed: open,
                ),
              ),
            ),
            child: _ProfilesContent(
              profiles: state.profiles,
              currentProfileId: state.currentProfileId,
              spacing: spacing,
              picker: picker,
            ),
          ),
        );
      },
    );
  }
}

class _ProfilesContent extends ConsumerStatefulWidget {
  const _ProfilesContent({
    required this.profiles,
    required this.currentProfileId,
    required this.spacing,
    required this.picker,
  });

  final List<Profile> profiles;
  final int? currentProfileId;
  final double spacing;
  final bool picker;

  @override
  ConsumerState<_ProfilesContent> createState() => _ProfilesContentState();
}

class _ProfilesContentState extends ConsumerState<_ProfilesContent> {
  static const _horizontalPadding = 16.0;

  ScrollController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  int _columnsFor(double width) {
    final contentWidth = width - _horizontalPadding * 2;
    if (width < _wideBoardingPassBreakpoint) {
      return 1;
    }
    return getProfilesColumns(
      contentWidth,
      spacing: widget.spacing,
      minItemWidth: profileItemMinWidth.ap(context),
    ).clamp(1, 3);
  }

  void _selectProfile(int? profileId) {
    ref.read(currentProfileIdProvider.notifier).value = profileId;
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.profiles;
    final topPadding = context.contentTopPadding;
    final bottomPadding = 16 + context.bottomInset;

    return LayoutBuilder(
      builder: (context, constraints) {
        _controller ??= sheetScrollController(context);
        final width = constraints.maxWidth;
        final isWide = width >= _wideBoardingPassBreakpoint;
        final columns = _columnsFor(width);

        if (widget.picker) {
          return GridView.builder(
            key: profilesStoreKey,
            controller: _controller,
            padding: EdgeInsets.fromLTRB(
              _horizontalPadding,
              topPadding,
              _horizontalPadding,
              bottomPadding,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: widget.spacing,
              crossAxisSpacing: widget.spacing,
              mainAxisExtent: _profileItemHeight,
            ),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return ProfileItem(
                key: ValueKey(profile.id),
                profile: profile,
                groupValue: widget.currentProfileId,
                showSelectionBadge: true,
                onChanged: _selectProfile,
              );
            },
          );
        }

        final activeProfile = profiles.getProfile(widget.currentProfileId);
        final otherProfiles = activeProfile == null
            ? profiles
            : [
                for (final profile in profiles)
                  if (profile.id != activeProfile.id) profile,
              ];

        return CustomScrollView(
          key: profilesStoreKey,
          controller: _controller,
          slivers: [
            if (activeProfile != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  topPadding,
                  _horizontalPadding,
                  otherProfiles.isEmpty ? bottomPadding : 0,
                ),
                sliver: SliverToBoxAdapter(
                  child: ProfileBoardingPass(
                    key: ValueKey('hero-${activeProfile.id}'),
                    profile: activeProfile,
                    isWide: isWide,
                  ),
                ),
              ),
            if (otherProfiles.isNotEmpty) ...[
              SliverPadding(
                padding: EdgeInsets.only(
                  left: _horizontalPadding,
                  right: _horizontalPadding,
                  top: activeProfile != null ? 0 : topPadding,
                ),
                sliver: SliverToBoxAdapter(
                  child: ListHeader(
                    title: context.appLocalizations.otherProfiles,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  0,
                  _horizontalPadding,
                  bottomPadding,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: widget.spacing,
                    crossAxisSpacing: widget.spacing,
                    mainAxisExtent: _profileItemHeight,
                  ),
                  itemCount: otherProfiles.length,
                  itemBuilder: (context, index) {
                    final profile = otherProfiles[index];
                    return ProfileItem(
                      key: ValueKey(profile.id),
                      profile: profile,
                      groupValue: widget.currentProfileId,
                      onChanged: _selectProfile,
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class ProfileItem extends ConsumerWidget {
  final Profile profile;
  final int? groupValue;
  final void Function(int? value) onChanged;
  final bool showSelectionBadge;

  const ProfileItem({
    super.key,
    required this.profile,
    required this.groupValue,
    required this.onChanged,
    this.showSelectionBadge = false,
  });

  Widget _buildRightAnchor(
    BuildContext context, {
    required bool isUpdating,
    required int? customCount,
  }) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    if (isUpdating) {
      return const ActivityIndicator(size: 22);
    }

    final expired = profileIsExpired(profile);
    if (expired) {
      return TitleChip(label: l.expired, color: colorScheme.error);
    }

    final primaryStyle = AppTextStyle.footnote
        .of(context, emphasized: true)
        .toTabular
        .copyWith(color: colorScheme.onSurface, height: 1.15);
    final secondaryStyle = AppTextStyle.caption2
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant, height: 1.15);

    Widget labeledAnchor({
      required String top,
      required String bottom,
      required Widget graphic,
      String? tooltip,
    }) {
      final row = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(top, maxLines: 1, style: primaryStyle),
              const SizedBox(height: 2),
              Text(bottom, maxLines: 1, style: secondaryStyle),
            ],
          ),
          graphic,
        ],
      );
      return tooltip == null ? row : Tooltip(message: tooltip, child: row);
    }

    final usage = profileUsageOf(profile);
    if (usage != null) {
      return labeledAnchor(
        top: dashboardTraffic(usage.remaining),
        bottom: l.remainingShort,
        graphic: ProfileTrafficRing(share: usage.share, size: 28),
      );
    }

    return switch (profile.type) {
      ProfileType.url => labeledAnchor(
        top: l.infiniteTime,
        bottom: l.remote,
        graphic: const ProfileTypeBadgeCircle(type: ProfileType.url, size: 28),
      ),
      ProfileType.file => labeledAnchor(
        top: 'YAML',
        bottom: l.local,
        graphic: const ProfileTypeBadgeCircle(type: ProfileType.file, size: 28),
      ),
      ProfileType.custom => labeledAnchor(
        top: customCount != null ? l.groupCount(customCount) : l.custom,
        bottom: l.custom,
        tooltip: customCount != null
            ? l.proxyGroupsCount(customCount, customCount.compact)
            : null,
        graphic: const ProfileTypeBadgeCircle(
          type: ProfileType.custom,
          size: 28,
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUpdating = ref.watch(isUpdatingProvider(profile.updatingKey));
    final customCount = profile.type == ProfileType.custom
        ? ref.watch(profileGroupsCountProvider(profile.id)).value
        : null;
    final isSelected = profile.id == groupValue;
    final expired = profileIsExpired(profile);
    final colorScheme = context.colorScheme;
    final menuItems = buildProfileMenuItems(context, ref, profile);

    return ContextMenuRegion(
      menuItems: isUpdating ? null : menuItems,
      child: Card(
        enterActionsOnRight: true,
        radius: AppCorner.xl,
        isSelected: isSelected,
        onPressed: () {
          onChanged(profile.id);
        },
        child: Padding(
          key: Key(profile.id.toString()),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: _cardVerticalPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileIconBadge(profile: profile, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EmojiText(
                      profile.realLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.headline.of(context),
                    ),
                    const SizedBox(height: _infoGap),
                    Text(
                      profileSubtitleText(context, profile),
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
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  _buildRightAnchor(
                    context,
                    isUpdating: isUpdating,
                    customCount: customCount,
                  ),
                  if (showSelectionBadge && isSelected)
                    const SelectionBadge(size: 22),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReorderableProfilesSheet extends ConsumerStatefulWidget {
  final List<Profile> profiles;

  const ReorderableProfilesSheet({super.key, required this.profiles});

  @override
  ConsumerState<ReorderableProfilesSheet> createState() =>
      _ReorderableProfilesSheetState();
}

class _ReorderableProfilesSheetState
    extends ConsumerState<ReorderableProfilesSheet> {
  late List<Profile> profiles;

  @override
  void initState() {
    super.initState();
    profiles = List.from(widget.profiles);
  }

  Widget _buildItem(int index) {
    final position = ItemPosition.get(index, profiles.length);
    final profile = profiles[index];
    return ReorderDragStartListener(
      key: Key(profile.id.toString()),
      index: index,
      child: ItemPositionProvider(
        position: position,
        child: DecorationListItem(
          contentPadding: const EdgeInsets.only(left: 16),
          trailing: SortHandle(index: index),
          title: Text(profile.realLabel),
        ),
      ),
    );
  }

  void _handleSave() {
    Navigator.of(context).pop();
    final latest = ref.read(profilesProvider);
    final ids = {for (final profile in profiles) profile.id};
    ref.read(profilesProvider.notifier).reorder([
      for (final profile in profiles) ?latest.getProfile(profile.id),
      for (final profile in latest)
        if (!ids.contains(profile.id)) profile,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Scaffold(
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        onPressed: _handleSave,
        tooltip: context.appLocalizations.save,
      ),
      body: PrismReorderableListView(
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
          top: context.contentTopPadding,
          bottom: 32 + context.bottomInset,
        ),
        proxyDecorator: (child, index, animation) {
          return commonProxyDecorator(_buildItem(index), index, animation);
        },
        onReorderItem: (oldIndex, newIndex) {
          setState(() {
            profiles = profiles.copyAndReorder(oldIndex, newIndex);
          });
        },
        itemBuilder: (_, index) {
          return _buildItem(index);
        },
        itemCount: profiles.length,
      ),
      title: appLocalizations.profilesSort,
    );
  }
}
