import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/manager/font_manager.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

sealed class _FontChoice {
  const _FontChoice();
}

final class _DefaultFont extends _FontChoice {
  const _DefaultFont();

  @override
  bool operator ==(Object other) => other is _DefaultFont;

  @override
  int get hashCode => 0;
}

final class _CustomFontChoice extends _FontChoice {
  const _CustomFontChoice(this.font);

  final CustomFont font;

  @override
  bool operator ==(Object other) =>
      other is _CustomFontChoice && other.font.path == font.path;

  @override
  int get hashCode => font.path.hashCode;
}

class FontFamilyView extends StatefulWidget {
  const FontFamilyView({super.key});

  @override
  State<FontFamilyView> createState() => _FontFamilyViewState();
}

class _FontFamilyViewState extends State<FontFamilyView> {
  Future<void> _handlePickFont() async {
    final imported = await FontManager.importAndSelect(context);
    if (!mounted || !imported) {
      return;
    }
    setState(() {});
  }

  Future<void> _handleExportFont(CustomFont font) async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.safeRun<bool>(() async {
      final file = File(font.path);
      if (!await file.exists()) {
        return false;
      }
      final value = await picker.saveFile(
        font.name,
        await file.readAsBytes(),
      );
      if (value == null) return false;
      return true;
    }, title: appLocalizations.tip);
    if (res == true && mounted) {
      dialogs.showBanner(
        appLocalizations.exportSuccess,
        level: BannerLevel.success,
      );
    }
  }

  Future<void> _handleDeleteFont(CustomFont font) async {
    final appLocalizations = context.appLocalizations;
    final result = await dialogs.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.deleteTip(font.name)),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (result != true || !mounted) {
      return;
    }
    await FontManager.delete(font);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final fonts = FontManager.fonts;
    return SelectionSheet<_FontChoice>(
      title: appLocalizations.fontFamily,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.addCircle,
          tooltip: appLocalizations.add,
          onPressed: _handlePickFont,
        ),
      ],
      sections: [
        const SelectionSection<_FontChoice>(items: [_DefaultFont()]),
        if (fonts.isNotEmpty)
          SelectionSection<_FontChoice>(
            label: appLocalizations.customFont,
            items: fonts.map(_CustomFontChoice.new).toList(),
          ),
      ],
      labelBuilder: (choice) => switch (choice) {
        _DefaultFont() => appLocalizations.defaultText,
        _CustomFontChoice(:final font) => font.name,
      },
      titleBuilder: (choice, title) => switch (choice) {
        _DefaultFont() => title,
        _CustomFontChoice(:final font) => switch (FontManager.familyOf(font)) {
          final family? => Text(
            font.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: family),
          ),
          null => title,
        },
      },
      selectedOf: (_) {
        final selected = FontManager.selectedFont;
        return selected == null
            ? const _DefaultFont()
            : _CustomFontChoice(selected);
      },
      menuBuilder: (choice) => switch (choice) {
        _CustomFontChoice(:final font) => [
          PopupMenuItem(
            glyph: AppGlyphs.export,
            label: appLocalizations.exportFile,
            onPressed: () => _handleExportFont(font),
          ),
          PopupMenuItem(
            danger: true,
            glyph: AppGlyphs.delete,
            label: appLocalizations.delete,
            onPressed: () => _handleDeleteFont(font),
          ),
        ],
        _ => null,
      },
      onSelected: (choice) async {
        switch (choice) {
          case _DefaultFont():
            await FontManager.selectDefault();
          case _CustomFontChoice(:final font):
            await FontManager.select(font);
        }
        if (mounted) {
          setState(() {});
        }
      },
    );
  }
}
