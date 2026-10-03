import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/offline_map_pack.dart';

class OfflineMapPackStorage {
  const OfflineMapPackStorage._();

  static const String _packsDirectoryName = 'prism_map_packs';
  static const String _metadataFileName = 'metadata.json';

  static Future<Directory> getPacksDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();

    final directory = Directory(
      '${appDirectory.path}/$_packsDirectoryName',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  static Future<Directory> getPackDirectory(String packId) async {
    final packsDirectory = await getPacksDirectory();

    final directory = Directory(
      '${packsDirectory.path}/$packId',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  static Future<File> getMbtilesFile(String packId) async {
    final packDirectory = await getPackDirectory(packId);

    return File(
      '${packDirectory.path}/map.mbtiles',
    );
  }

  static Future<File> getMetadataFile(String packId) async {
    final packDirectory = await getPackDirectory(packId);

    return File(
      '${packDirectory.path}/$_metadataFileName',
    );
  }

  static Future<List<OfflineMapPack>> getInstalledPacks() async {
    final packsDirectory = await getPacksDirectory();

    final entries = await packsDirectory.list().toList();

    final packs = <OfflineMapPack>[];

    for (final entry in entries) {
      if (entry is! Directory) continue;

      final metadataFile = File(
        '${entry.path}/$_metadataFileName',
      );

      if (!await metadataFile.exists()) continue;

      try {
        final content = await metadataFile.readAsString();

        if (content.trim().isEmpty) continue;

        final json = jsonDecode(content);

        if (json is Map<String, dynamic>) {
          packs.add(
            OfflineMapPack.fromJson(json),
          );
        }
      } catch (_) {
        // Ignore invalid metadata and continue with other packs.
      }
    }

    return packs;
  }

  static Future<void> savePack(OfflineMapPack pack) async {
    final metadataFile = await getMetadataFile(pack.id);

    await metadataFile.writeAsString(
      jsonEncode(pack.toJson()),
    );
  }

  static Future<bool> isPackInstalled(String packId) async {
    final metadataFile = await getMetadataFile(packId);
    final mbtilesFile = await getMbtilesFile(packId);

    return await metadataFile.exists() &&
        await mbtilesFile.exists() &&
        await mbtilesFile.length() > 0;
  }

  static Future<void> removePack(String packId) async {
    final packsDirectory = await getPacksDirectory();

    final packDirectory = Directory(
      '${packsDirectory.path}/$packId',
    );

    if (await packDirectory.exists()) {
      await packDirectory.delete(recursive: true);
    }
  }

  static Future<int> getPackSizeBytes(String packId) async {
    final file = await getMbtilesFile(packId);

    if (!await file.exists()) {
      return 0;
    }

    return await file.length();
  }
}
