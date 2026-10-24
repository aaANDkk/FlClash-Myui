import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// A font the user imported, copied into the app's own fonts directory.
class CustomFont {
  const CustomFont({required this.name, required this.path});

  /// What the list and the theme card show, such as `sleek.ttf`.
  final String name;

  /// Absolute path of the copied file.
  final String path;

  Map<String, String> toJson() => {'name': name, 'path': path};

  static CustomFont? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final name = json['name'];
    final path = json['path'];
    if (name is! String || path is! String) {
      return null;
    }
    if (name.isEmpty || path.isEmpty) {
      return null;
    }
    return CustomFont(name: name, path: path);
  }
}

class _FontMetrics {
  const _FontMetrics({required this.isVariable, required this.baseWeight});

  final bool isVariable;
  final int baseWeight;
}

class FontManager {
  static final ValueNotifier<String?> fontFamilyNotifier =
      ValueNotifier<String?>(null);

  static List<CustomFont> _fonts = const [];
  static final Map<String, String> _families = {};
  static final Map<String, _FontMetrics> _metrics = {};
  static String? _selectedPath;

  static const String _prefKeyFonts = 'custom_fonts';
  static const String _prefKeySelected = 'custom_font_selected';
  static const String _prefKeyLegacyName = 'custom_font_name';
  static const String _prefKeyLegacyPath = 'custom_font_path';

  static List<CustomFont> get fonts => List.unmodifiable(_fonts);

  static CustomFont? get selectedFont {
    final selectedPath = _selectedPath;
    if (selectedPath == null) {
      return null;
    }
    for (final font in _fonts) {
      if (font.path == selectedPath) {
        return font;
      }
    }
    return null;
  }

  static String? get selectedName => selectedFont?.name;

  /// The family the theme paints with, or null while the default font is picked.
  static String? get customFontFamily => fontFamilyNotifier.value;

  static bool get isLoaded => fontFamilyNotifier.value != null;

  static bool get isVariableFont => _selectedMetrics?.isVariable ?? false;

  static int get fontBaseWeight => _selectedMetrics?.baseWeight ?? 400;

  static _FontMetrics? get _selectedMetrics {
    final selectedPath = _selectedPath;
    return selectedPath == null ? null : _metrics[selectedPath];
  }

  /// The registered family for [font], null until the font has been loaded.
  static String? familyOf(CustomFont font) => _families[font.path];

  static Future<bool> init({required bool enabled}) async {
    try {
      final prefs = await preferences.sharedPreferences;
      final fonts = <CustomFont>[];
      final stored = prefs?.getString(_prefKeyFonts);
      if (stored != null && stored.isNotEmpty) {
        for (final font in _decode(stored)) {
          if (File(font.path).existsSync()) {
            fonts.add(font);
          }
        }
      }
      if (fonts.isEmpty) {
        final migrated = await _migrateLegacyFont(prefs);
        if (migrated != null) {
          fonts.add(migrated);
        }
      }
      _fonts = fonts;
      final storedSelection = prefs?.getString(_prefKeySelected);
      _selectedPath = fonts.any((font) => font.path == storedSelection)
          ? storedSelection
          : null;
      fontFamilyNotifier.value = null;
      final selectedPath = _selectedPath;
      if (enabled) {
        // Every font is registered, not just the selected one: the list previews
        // each face in its own typeface, and a family that was never loaded
        // previews as whatever the theme paints instead.
        for (final font in _fonts) {
          await _register(font.path);
        }
        if (selectedPath != null) {
          final family = _families[selectedPath];
          if (family == null) {
            _selectedPath = null;
          } else {
            fontFamilyNotifier.value = family;
          }
        }
      }
      await _persist();
      return _fonts.isNotEmpty;
    } catch (e, stack) {
      commonPrint.log('FontManager.init failed: $e\n$stack');
      return false;
    }
  }

  static Future<CustomFont?> _migrateLegacyFont(SharedPreferences? prefs) async {
    final legacyPath = prefs?.getString(_prefKeyLegacyPath);
    String? path;
    if (legacyPath != null &&
        legacyPath.isNotEmpty &&
        File(legacyPath).existsSync()) {
      path = legacyPath;
    } else {
      final homeDir = await appPath.homeDirPath;
      for (final extension in const ['.ttf', '.otf']) {
        final file = File(p.join(homeDir, 'fonts', 'user_custom$extension'));
        if (file.existsSync()) {
          path = file.path;
          break;
        }
      }
    }
    if (path == null) {
      return null;
    }
    final legacyName = prefs?.getString(_prefKeyLegacyName);
    final name = legacyName != null && legacyName.isNotEmpty
        ? legacyName
        : p.basename(path);
    return CustomFont(name: name, path: path);
  }

  static List<CustomFont> _decode(String raw) {
    final fonts = <CustomFont>[];
    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          final font = CustomFont.fromJson(item);
          if (font != null) {
            fonts.add(font);
          }
        }
      }
    } catch (_) {
      return const [];
    }
    return fonts;
  }

  static Future<void> _persist() async {
    try {
      final prefs = await preferences.sharedPreferences;
      if (prefs == null) {
        return;
      }
      await prefs.setString(
        _prefKeyFonts,
        json.encode([for (final font in _fonts) font.toJson()]),
      );
      final selectedPath = _selectedPath;
      if (selectedPath == null) {
        await prefs.remove(_prefKeySelected);
      } else {
        await prefs.setString(_prefKeySelected, selectedPath);
      }
    } catch (e, stack) {
      commonPrint.log('FontManager.persist failed: $e\n$stack');
    }
  }

  static Future<bool> select(CustomFont font) async {
    final family = await _register(font.path);
    if (family == null) {
      return false;
    }
    _selectedPath = font.path;
    fontFamilyNotifier.value = family;
    await _persist();
    return true;
  }

  static Future<void> selectDefault() async {
    _selectedPath = null;
    fontFamilyNotifier.value = null;
    await _persist();
  }

  static Future<void> delete(CustomFont font) async {
    _fonts = [
      for (final item in _fonts)
        if (item.path != font.path) item,
    ];
    _families.remove(font.path);
    _metrics.remove(font.path);
    if (_selectedPath == font.path) {
      _selectedPath = null;
      fontFamilyNotifier.value = null;
    }
    try {
      final file = File(font.path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      commonPrint.log('FontManager.delete failed: $e');
    }
    await _persist();
  }

  /// Copies the picked font next to the others and makes it the active one, so
  /// importing a second font keeps the first instead of replacing it.
  static Future<bool> importAndSelect(BuildContext context) async {
    try {
      final picked = await picker.pickerFile(allowedExtensions: ['ttf', 'otf']);
      if (picked == null) {
        return false;
      }
      final sourcePath = picked.path;
      if (sourcePath == null || sourcePath.isEmpty) {
        return false;
      }
      final extension = p.extension(picked.name).toLowerCase();
      if (extension != '.ttf' && extension != '.otf') {
        return false;
      }
      final bytes = await File(sourcePath).readAsBytes();
      if (bytes.isEmpty) {
        return false;
      }
      final fontsDir = Directory(p.join(await appPath.homeDirPath, 'fonts'));
      if (!await fontsDir.exists()) {
        await fontsDir.create(recursive: true);
      }
      final target = await _uniqueTarget(fontsDir, picked.name, extension);
      await File(target).writeAsBytes(bytes, flush: true);
      var name = picked.name;
      if (_fonts.any((font) => font.name == name)) {
        name =
            '${p.basenameWithoutExtension(name)} (${_fonts.length + 1})'
            '$extension';
      }
      final font = CustomFont(name: name, path: target);
      _fonts = [..._fonts, font];
      return await select(font);
    } catch (e, stack) {
      commonPrint.log('FontManager.import failed: $e\n$stack');
      return false;
    }
  }

  static Future<String> _uniqueTarget(
    Directory directory,
    String name,
    String extension,
  ) async {
    final base = p.basenameWithoutExtension(name).trim();
    final stem = base.isEmpty
        ? 'font'
        : base.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    var candidate = p.join(directory.path, '$stem$extension');
    var index = 2;
    while (await File(candidate).exists()) {
      candidate = p.join(directory.path, '$stem ($index)$extension');
      index++;
    }
    return candidate;
  }

  static Future<String?> _register(String filePath) async {
    final cached = _families[filePath];
    if (cached != null) {
      return cached;
    }
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      final rawBytes = await file.readAsBytes();
      if (rawBytes.isEmpty) {
        return null;
      }
      final processed = _analyzeAndProcessFont(rawBytes);
      final familyName = 'CustomUserFont_${filePath.hashCode.abs()}';
      final fontLoader = FontLoader(familyName);
      fontLoader.addFont(
        Future.value(
          ByteData.view(
            processed.bytes.buffer,
            processed.bytes.offsetInBytes,
            processed.bytes.lengthInBytes,
          ),
        ),
      );
      await fontLoader.load();
      _metrics[filePath] = _FontMetrics(
        isVariable: processed.isVariable,
        baseWeight: processed.baseWeight,
      );
      _families[filePath] = familyName;
      return familyName;
    } catch (e, stack) {
      commonPrint.log('FontManager.load failed: $e\n$stack');
      return null;
    }
  }

  static int _calcTableChecksum(
    Uint8List bytes,
    ByteData byteData,
    int offset,
    int length,
  ) {
    int sum = 0;
    final nLongs = (length + 3) ~/ 4;
    for (int i = 0; i < nLongs; i++) {
      final pos = offset + i * 4;
      int word = 0;
      if (pos + 4 <= bytes.length) {
        word = byteData.getUint32(pos, Endian.big);
      } else {
        for (int b = 0; b < 4; b++) {
          final p = pos + b;
          final bVal = (p < offset + length && p < bytes.length) ? bytes[p] : 0;
          word = (word << 8) | bVal;
        }
      }
      sum = (sum + word) & 0xFFFFFFFF;
    }
    return sum;
  }

  static _ProcessedFontData _analyzeAndProcessFont(Uint8List rawBytes) {
    if (rawBytes.length < 12) {
      return _ProcessedFontData(
        bytes: rawBytes,
        isVariable: false,
        baseWeight: 400,
      );
    }

    final bytes = Uint8List.fromList(rawBytes);
    final byteData = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );

    final magic = byteData.getUint32(0, Endian.big);
    final isTtc = (magic == 0x74746366); // 'ttcf'

    final List<int> fontOffsets = [];
    if (isTtc) {
      if (bytes.length >= 12) {
        final numFonts = byteData.getUint32(8, Endian.big);
        for (int i = 0; i < numFonts; i++) {
          final off = 12 + i * 4;
          if (off + 4 <= bytes.length) {
            fontOffsets.add(byteData.getUint32(off, Endian.big));
          }
        }
      }
    } else {
      fontOffsets.add(0);
    }

    bool isVariable = false;
    int originalWeight = 400;
    bool modified = false;

    for (final base in fontOffsets) {
      if (base + 12 > bytes.length) continue;
      final numTables = byteData.getUint16(base + 4, Endian.big);

      int? os2RecOffset;
      int? os2Offset;
      int? os2Length;
      int? headOffset;

      for (int i = 0; i < numTables; i++) {
        final rec = base + 12 + i * 16;
        if (rec + 16 > bytes.length) break;

        final tag = byteData.getUint32(rec, Endian.big);
        final offset = byteData.getUint32(rec + 8, Endian.big);
        final length = byteData.getUint32(rec + 12, Endian.big);

        if (tag == 0x66766172) {
          // 'fvar'
          isVariable = true;
        } else if (tag == 0x4F532F32) {
          // 'OS/2'
          os2RecOffset = rec;
          os2Offset = offset;
          os2Length = length;
        } else if (tag == 0x68656164) {
          // 'head'
          headOffset = offset;
        }
      }

      if (os2Offset != null && os2Offset + 6 <= bytes.length) {
        final weight = byteData.getUint16(os2Offset + 4, Endian.big);
        originalWeight = weight;

        // If static font has usWeightClass > 400 (e.g. 700 bold), normalize to 400 so Skia
        // can apply fake-bold to titles and does not force body text to be bold.
        if (!isVariable &&
            weight > 400 &&
            os2RecOffset != null &&
            os2Length != null) {
          byteData.setUint16(os2Offset + 4, 400, Endian.big);

          if (os2Offset + 64 <= bytes.length) {
            int fsSel = byteData.getUint16(os2Offset + 62, Endian.big);
            if ((fsSel & 0x0020) != 0) {
              fsSel = (fsSel & ~0x0020) | 0x0040;
              byteData.setUint16(os2Offset + 62, fsSel, Endian.big);
            }
          }

          final newCksum = _calcTableChecksum(
            bytes,
            byteData,
            os2Offset,
            os2Length,
          );
          byteData.setUint32(os2RecOffset + 4, newCksum, Endian.big);

          if (headOffset != null && headOffset + 12 <= bytes.length && !isTtc) {
            byteData.setUint32(headOffset + 8, 0, Endian.big);
            final totalCksum = _calcTableChecksum(
              bytes,
              byteData,
              0,
              bytes.length,
            );
            final adj = (0xB1B0AFBA - totalCksum) & 0xFFFFFFFF;
            byteData.setUint32(headOffset + 8, adj, Endian.big);
          }

          modified = true;
        }
      }
    }

    return _ProcessedFontData(
      bytes: modified ? bytes : rawBytes,
      isVariable: isVariable,
      baseWeight: originalWeight,
    );
  }
}

class _ProcessedFontData {
  final Uint8List bytes;
  final bool isVariable;
  final int baseWeight;

  const _ProcessedFontData({
    required this.bytes,
    required this.isVariable,
    required this.baseWeight,
  });
}
