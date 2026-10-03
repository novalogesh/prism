import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class OfflineMbtilesService {
  const OfflineMbtilesService._();

  static const String _assetPath =
      'assets/maps/prism_rmkcet.mbtiles';

  static const String _directoryName = 'prism_offline_maps';

  static const String _fileName = 'prism_rmkcet.mbtiles';

  static const String _tempSuffix = '.tmp';

  static const List<String> _sidecarSuffixes = ['-wal', '-shm', '-journal'];

  /// First 16 bytes of every SQLite database file ("SQLite format 3\0").
  static final List<int> _sqliteHeader = 'SQLite format 3\u0000'.codeUnits;

  /// Refreshes already running for a target path. The temporary file has a
  /// fixed name, so overlapping calls share one refresh instead of writing it
  /// concurrently.
  static final Map<String, Future<String>> _inFlight = {};

  /// Copies the bundled MBTiles asset to a real filesystem location and
  /// returns its path.
  ///
  /// MbTilesVectorTileProvider.open() requires a filesystem path,
  /// so the Flutter asset is copied to the application support directory.
  ///
  /// The copy is refreshed on every call so an updated bundled map replaces
  /// the one left by an older app version. The asset is written to a
  /// temporary file and moved over the target, so the target is always either
  /// the old complete copy or the new complete copy. If the refresh fails and
  /// a usable copy already exists, that copy is returned; if there is none,
  /// the error is rethrown.
  static Future<String> prepare() async {
    final supportDirectory = await getApplicationSupportDirectory();

    return prepareWith(
      supportDirectory: supportDirectory,
      bundle: rootBundle,
    );
  }

  /// Same as [prepare] with the support directory and asset bundle supplied
  /// by the caller. Only for tests; the app uses [prepare].
  @visibleForTesting
  static Future<String> prepareWith({
    required Directory supportDirectory,
    required AssetBundle bundle,
  }) {
    final targetPath = '${supportDirectory.path}/$_directoryName/$_fileName';

    final running = _inFlight[targetPath];
    if (running != null) return running;

    final refresh = _refresh(supportDirectory, bundle).whenComplete(() {
      // Block body on purpose: an expression body would return the removed
      // future, and whenComplete would then wait on itself.
      _inFlight.remove(targetPath);
    });

    _inFlight[targetPath] = refresh;

    return refresh;
  }

  static Future<String> _refresh(
    Directory supportDirectory,
    AssetBundle bundle,
  ) async {
    final mapDirectory = Directory(
      '${supportDirectory.path}/$_directoryName',
    );

    if (!await mapDirectory.exists()) {
      await mapDirectory.create(recursive: true);
    }

    final targetFile = File(
      '${mapDirectory.path}/$_fileName',
    );

    final tempFile = File(
      '${targetFile.path}$_tempSuffix',
    );

    // Leftovers from a refresh that was interrupted in an earlier run.
    await _deleteWithSidecars(tempFile);

    try {
      final data = await bundle.load(_assetPath);

      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await tempFile.writeAsBytes(bytes, flush: true);

      // Never replace a working copy with a truncated or non-SQLite file.
      if (await tempFile.length() != bytes.length ||
          !await _isUsableMbtiles(tempFile)) {
        throw FileSystemException(
          'Bundled MBTiles asset is empty or not a SQLite database',
          tempFile.path,
        );
      }

      // Replaces an existing target in a single step.
      await tempFile.rename(targetFile.path);
    } catch (error) {
      await _deleteWithSidecars(tempFile);

      // The target and its sidecars are left alone here: the target is still
      // the previous copy, and a hot journal next to it may be needed to
      // open it safely.
      if (await _isUsableMbtiles(targetFile)) {
        debugPrint(
          'Offline MBTiles refresh failed, using existing copy: $error',
        );

        return targetFile.path;
      }

      rethrow;
    }

    // The database file was just replaced, so any sidecars still next to the
    // target belong to the old file and must not be applied to the new one.
    await _deleteSidecars(targetFile);

    return targetFile.path;
  }

  /// True when [file] exists and starts with the SQLite file header.
  static Future<bool> _isUsableMbtiles(File file) async {
    try {
      if (!await file.exists()) return false;

      final handle = await file.open();

      try {
        final head = await handle.read(_sqliteHeader.length);

        if (head.length != _sqliteHeader.length) return false;

        for (var i = 0; i < head.length; i++) {
          if (head[i] != _sqliteHeader[i]) return false;
        }

        return true;
      } finally {
        await handle.close();
      }
    } catch (_) {
      return false;
    }
  }

  static Future<void> _deleteWithSidecars(File file) async {
    await _deleteIfExists(file);
    await _deleteSidecars(file);
  }

  static Future<void> _deleteSidecars(File file) async {
    for (final suffix in _sidecarSuffixes) {
      await _deleteIfExists(File('${file.path}$suffix'));
    }
  }

  static Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort. A leftover is cleaned up by the next prepare().
    }
  }
}
