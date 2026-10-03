import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class OfflineMbtilesService {
  const OfflineMbtilesService._();

  static const String _assetPath =
      'assets/maps/prism_rmkcet.mbtiles';

  static const String _fileName = 'prism_rmkcet.mbtiles';

  /// Copies the bundled MBTiles asset to a real filesystem location.
  ///
  /// MbTilesVectorTileProvider.open() requires a filesystem path,
  /// so the Flutter asset is copied to the application support directory.
  static Future<String> prepare() async {
    final supportDirectory = await getApplicationSupportDirectory();

    final mapDirectory = Directory(
      '${supportDirectory.path}/prism_offline_maps',
    );

    if (!await mapDirectory.exists()) {
      await mapDirectory.create(recursive: true);
    }

    final targetFile = File(
      '${mapDirectory.path}/$_fileName',
    );

    if (await targetFile.exists() && await targetFile.length() > 0) {
      return targetFile.path;
    }

    final data = await rootBundle.load(_assetPath);

    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    await targetFile.writeAsBytes(bytes, flush: true);

    return targetFile.path;
  }
}