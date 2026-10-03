import 'dart:io';

import 'package:path_provider/path_provider.dart';

class OfflineMapStorage {
  const OfflineMapStorage._();

  static Future<Directory> getMapDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();

    final mapDirectory = Directory(
      '${appDirectory.path}/prism_offline_maps',
    );

    if (!await mapDirectory.exists()) {
      await mapDirectory.create(recursive: true);
    }

    return mapDirectory;
  }

  static Future<bool> isOfflineMapAvailable() async {
    final directory = await getMapDirectory();

    return directory.existsSync() &&
        directory.listSync().isNotEmpty;
  }
}
