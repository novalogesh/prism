class OfflineMapConfig {
  const OfflineMapConfig._();

  /// Whether PRISM should use locally stored map tiles.
  ///
  /// Keep this false until the actual offline tile dataset
  /// has been added to assets/maps.
  static const bool useOfflineTiles = false;

  static const String onlineTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String offlineTilePath =
      'assets/maps/{z}/{x}/{y}.png';
}
