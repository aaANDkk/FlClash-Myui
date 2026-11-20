import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists optional user-picked icons (from icon sets or links) keyed by
/// profile ID. An empty or absent entry falls back to the profile type's
/// built-in default glyph.
class ProfileIconsNotifier extends Notifier<Map<int, String>> {
  var _mutated = false;

  @override
  Map<int, String> build() {
    _mutated = false;
    unawaited(_restore());
    return const {};
  }

  Future<void> _restore() async {
    try {
      final raw = await preferences.getProfileIcons();
      if (_mutated || raw == null || raw.isEmpty) {
        return;
      }
      final decoded = json.decode(raw);
      if (decoded is! Map) {
        return;
      }
      final restored = <int, String>{};
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key.toString());
        final src = entry.value is String ? (entry.value as String).trim() : '';
        if (id != null && src.isNotEmpty) {
          restored[id] = src;
        }
      }
      if (!_mutated) {
        state = Map.unmodifiable(restored);
      }
    } catch (error) {
      commonPrint.log('restore profile icons error $error');
    }
  }

  Future<void> _save(Map<int, String> icons) async {
    try {
      final encoded = <String, String>{
        for (final entry in icons.entries) entry.key.toString(): entry.value,
      };
      await preferences.setProfileIcons(json.encode(encoded));
    } catch (error) {
      commonPrint.log('save profile icons error $error');
    }
  }

  void setIcon(int profileId, String icon) {
    _mutated = true;
    final trimmed = icon.trim();
    final next = Map<int, String>.from(state);
    if (trimmed.isEmpty) {
      if (next.remove(profileId) == null) {
        return;
      }
    } else {
      if (next[profileId] == trimmed) {
        return;
      }
      next[profileId] = trimmed;
    }
    state = Map.unmodifiable(next);
    unawaited(_save(state));
  }

  void removeIcon(int profileId) {
    _mutated = true;
    if (!state.containsKey(profileId)) {
      return;
    }
    final next = Map<int, String>.from(state)..remove(profileId);
    state = Map.unmodifiable(next);
    unawaited(_save(state));
  }
}

final profileIconsProvider =
    NotifierProvider<ProfileIconsNotifier, Map<int, String>>(
      ProfileIconsNotifier.new,
    );

final profileIconProvider = Provider.family<String, int>(
  (ref, profileId) =>
      ref.watch(profileIconsProvider.select((icons) => icons[profileId] ?? '')),
);
