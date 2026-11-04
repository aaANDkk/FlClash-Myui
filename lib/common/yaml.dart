import 'package:fl_clash/common/yaml_writer.dart';
import 'package:yaml/yaml.dart';

class Yaml {
  static Yaml? _instance;

  Yaml._internal();

  factory Yaml() {
    _instance ??= Yaml._internal();
    return _instance!;
  }

  String encode(Object? value) {
    return writeYaml(value);
  }
}

String unescapeYamlUnicode(String text) {
  if (!text.contains(r'\U') && !text.contains(r'\u')) {
    return text;
  }
  return text.replaceAllMapped(
    RegExp(r'(\\*)\\([Uu])([0-9a-fA-F]{4,8})'),
    (match) {
      final leadingSlashes = match[1]!;
      if (leadingSlashes.length.isOdd) {
        return match[0]!;
      }
      final type = match[2]!;
      final hex = match[3]!;
      if (type == 'U' && hex.length >= 8) {
        final code = int.tryParse(hex.substring(0, 8), radix: 16);
        if (code != null && code >= 0 && code <= 0x10FFFF) {
          return '$leadingSlashes${String.fromCharCode(code)}${hex.substring(8)}';
        }
      } else if (type == 'u' && hex.length >= 4) {
        final code = int.tryParse(hex.substring(0, 4), radix: 16);
        if (code != null) {
          return '$leadingSlashes${String.fromCharCode(code)}${hex.substring(4)}';
        }
      }
      return match[0]!;
    },
  );
}

final yaml = Yaml();

/// Applies `<<` merge keys as mihomo does; package:yaml keeps them as keys.
Object? loadPlainYaml(String content) => _plainYaml(loadYaml(content));

Object? _plainYaml(Object? node) => switch (node) {
  YamlMap() => _plainYamlMap(node),
  YamlList() => [for (final item in node) _plainYaml(item)],
  _ => node,
};

Map<String, Object?> _plainYamlMap(YamlMap node) {
  final map = <String, Object?>{};
  final merged = <Object?>[];
  for (final MapEntry(:key, :value) in node.entries) {
    if (key == '<<') {
      merged.addAll(value is YamlList ? value : [value]);
    } else {
      map[key.toString()] = _plainYaml(value);
    }
  }
  for (final item in merged) {
    if (item is YamlMap) {
      for (final MapEntry(:key, :value) in _plainYamlMap(item).entries) {
        map.putIfAbsent(key, () => value);
      }
    }
  }
  return map;
}
