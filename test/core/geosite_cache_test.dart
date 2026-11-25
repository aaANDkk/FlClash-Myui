import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'repairs the damaged bundled GeoSite and preserves other caches',
    () async {
      final home = await Directory.systemTemp.createTemp('geosite_cache_test');
      addTearDown(() => home.delete(recursive: true));
      await useAppPaths(home);
      for (final name in [MMDB, GEOIP, ASN]) {
        await File('${home.path}/$name').writeAsString('existing resource');
      }
      final bundled = await File('assets/data/$GEOSITE').readAsBytes();
      final legacy = Uint8List(bundled.length);
      var size = 0;
      for (var index = 0; index < bundled.length; index++) {
        if (bundled[index] == 13 &&
            index + 1 < bundled.length &&
            bundled[index + 1] == 10) {
          continue;
        }
        legacy[size++] = bundled[index];
      }
      final cached = File('${home.path}/$GEOSITE');
      final damaged = Uint8List.sublistView(legacy, 0, size);
      await cached.writeAsBytes(damaged);
      expect(size, bundled.length - 8);

      await CoreController.initGeo();

      expect(
        await sha256.bind(cached.openRead()).first,
        sha256.convert(bundled),
      );

      damaged[0] ^= 1;
      await cached.writeAsBytes(damaged);
      await CoreController.initGeo();

      expect(
        await sha256.bind(cached.openRead()).first,
        sha256.convert(damaged),
      );
    },
  );
}
