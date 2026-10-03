import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism/features/map/services/offline_mbtiles_service.dart';

const _assetKey = 'assets/maps/prism_rmkcet.mbtiles';

/// Smallest payload the service accepts: the SQLite header plus a tag so
/// different "versions" of the map can be told apart.
Uint8List _mbtiles(String tag) {
  return Uint8List.fromList([
    ...'SQLite format 3\u0000'.codeUnits,
    ...tag.codeUnits,
    ...List<int>.filled(64, 0),
  ]);
}

class _AssetFailure implements Exception {
  const _AssetFailure();
}

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(Uint8List this.bytes) : error = null;

  _FakeBundle.failing(Object this.error) : bytes = null;

  final Uint8List? bytes;
  final Object? error;

  final List<String> requestedKeys = [];

  /// When set, load() waits for it, which lets a test overlap two calls.
  Completer<void>? gate;

  int get loadCount => requestedKeys.length;

  @override
  Future<ByteData> load(String key) async {
    requestedKeys.add(key);

    final gate = this.gate;
    if (gate != null) await gate.future;

    final error = this.error;
    if (error != null) throw error;

    return ByteData.sublistView(bytes!);
  }
}

void main() {
  late Directory supportDirectory;
  late Directory mapDirectory;
  late File target;

  File sibling(String suffix) => File('${target.path}$suffix');

  Future<String> prepare(AssetBundle bundle) {
    return OfflineMbtilesService.prepareWith(
      supportDirectory: supportDirectory,
      bundle: bundle,
    );
  }

  void seedExistingCopy(Uint8List bytes) {
    mapDirectory.createSync(recursive: true);
    target.writeAsBytesSync(bytes);
  }

  List<String> filesInMapDirectory() {
    if (!mapDirectory.existsSync()) return [];
    return mapDirectory
        .listSync()
        .map((entity) => entity.path.split(Platform.pathSeparator).last)
        .toList()
      ..sort();
  }

  setUp(() {
    supportDirectory = Directory.systemTemp.createTempSync(
      'prism_mbtiles_test_',
    );
    mapDirectory = Directory('${supportDirectory.path}/prism_offline_maps');
    target = File('${mapDirectory.path}/prism_rmkcet.mbtiles');
  });

  tearDown(() {
    if (supportDirectory.existsSync()) {
      supportDirectory.deleteSync(recursive: true);
    }
  });

  group('initial copy', () {
    test('creates the map directory and copies the bundled asset', () async {
      final bundle = _FakeBundle(_mbtiles('v1'));

      expect(mapDirectory.existsSync(), isFalse);

      final path = await prepare(bundle);

      expect(path, target.path);
      expect(target.readAsBytesSync(), _mbtiles('v1'));
      expect(bundle.requestedKeys, [_assetKey]);
      expect(filesInMapDirectory(), ['prism_rmkcet.mbtiles']);
    });

    test('accepts the real bundled asset', () async {
      final real = File(_assetKey).readAsBytesSync();

      final path = await prepare(_FakeBundle(real));

      expect(File(path).readAsBytesSync(), real);
    });
  });

  group('refresh on every prepare', () {
    test('replaces an older existing copy with the bundled one', () async {
      seedExistingCopy(_mbtiles('old'));

      final path = await prepare(_FakeBundle(_mbtiles('new')));

      expect(path, target.path);
      expect(target.readAsBytesSync(), _mbtiles('new'));
      expect(filesInMapDirectory(), ['prism_rmkcet.mbtiles']);
    });

    test('loads the asset again on each call', () async {
      final bundle = _FakeBundle(_mbtiles('v1'));

      await prepare(bundle);
      await prepare(bundle);

      expect(bundle.loadCount, 2);
      expect(target.readAsBytesSync(), _mbtiles('v1'));
    });

    test('overlapping calls share one refresh, later calls start a new one',
        () async {
      final bundle = _FakeBundle(_mbtiles('v1'))..gate = Completer<void>();

      final first = prepare(bundle);
      final second = prepare(bundle);

      bundle.gate!.complete();

      expect(await first, target.path);
      expect(await second, target.path);
      expect(bundle.loadCount, 1);

      await prepare(bundle);

      expect(bundle.loadCount, 2);
    });
  });

  group('refresh fails', () {
    test('returns the existing copy untouched when one is usable', () async {
      seedExistingCopy(_mbtiles('old'));

      final path = await prepare(_FakeBundle.failing(const _AssetFailure()));

      expect(path, target.path);
      expect(target.readAsBytesSync(), _mbtiles('old'));
      expect(filesInMapDirectory(), ['prism_rmkcet.mbtiles']);
    });

    test('rethrows when there is no existing copy', () async {
      await expectLater(
        prepare(_FakeBundle.failing(const _AssetFailure())),
        throwsA(isA<_AssetFailure>()),
      );

      expect(target.existsSync(), isFalse);
      expect(filesInMapDirectory(), isEmpty);
    });

    test('rethrows when the existing copy is empty', () async {
      seedExistingCopy(Uint8List(0));

      await expectLater(
        prepare(_FakeBundle.failing(const _AssetFailure())),
        throwsA(isA<_AssetFailure>()),
      );
    });

    test('rethrows when the existing copy is not a SQLite file', () async {
      seedExistingCopy(Uint8List.fromList('not a database'.codeUnits));

      await expectLater(
        prepare(_FakeBundle.failing(const _AssetFailure())),
        throwsA(isA<_AssetFailure>()),
      );
    });
  });

  group('invalid bundled asset', () {
    final invalidAssets = <String, Uint8List>{
      'empty': Uint8List(0),
      'not a SQLite file': Uint8List.fromList('not a database'.codeUnits),
      'shorter than the SQLite header':
          Uint8List.fromList('SQLite format'.codeUnits),
    };

    for (final entry in invalidAssets.entries) {
      test('${entry.key}: keeps the existing copy', () async {
        seedExistingCopy(_mbtiles('old'));

        final path = await prepare(_FakeBundle(entry.value));

        expect(path, target.path);
        expect(target.readAsBytesSync(), _mbtiles('old'));
        expect(filesInMapDirectory(), ['prism_rmkcet.mbtiles']);
      });

      test('${entry.key}: throws when there is no existing copy', () async {
        await expectLater(
          prepare(_FakeBundle(entry.value)),
          throwsA(isA<FileSystemException>()),
        );

        expect(target.existsSync(), isFalse);
        expect(filesInMapDirectory(), isEmpty);
      });
    }
  });

  group('stale files', () {
    void seedStaleFiles() {
      mapDirectory.createSync(recursive: true);
      for (final suffix in ['.tmp', '.tmp-wal', '.tmp-shm', '.tmp-journal']) {
        sibling(suffix).writeAsBytesSync([1, 2, 3]);
      }
    }

    void seedTargetSidecars() {
      for (final suffix in ['-wal', '-shm', '-journal']) {
        sibling(suffix).writeAsBytesSync([1, 2, 3]);
      }
    }

    test('are removed after a successful refresh', () async {
      seedExistingCopy(_mbtiles('old'));
      seedStaleFiles();
      seedTargetSidecars();

      await prepare(_FakeBundle(_mbtiles('new')));

      expect(target.readAsBytesSync(), _mbtiles('new'));
      expect(filesInMapDirectory(), ['prism_rmkcet.mbtiles']);
    });

    test('temporary files are removed when the refresh fails, the existing '
        'copy and its sidecars are left alone', () async {
      seedExistingCopy(_mbtiles('old'));
      seedStaleFiles();
      seedTargetSidecars();

      final path = await prepare(_FakeBundle.failing(const _AssetFailure()));

      expect(path, target.path);
      expect(target.readAsBytesSync(), _mbtiles('old'));
      expect(filesInMapDirectory(), [
        'prism_rmkcet.mbtiles',
        'prism_rmkcet.mbtiles-journal',
        'prism_rmkcet.mbtiles-shm',
        'prism_rmkcet.mbtiles-wal',
      ]);
    });

    test('are removed on a first run with no existing copy', () async {
      seedStaleFiles();

      await prepare(_FakeBundle(_mbtiles('v1')));

      expect(filesInMapDirectory(), ['prism_rmkcet.mbtiles']);
    });
  });
}
