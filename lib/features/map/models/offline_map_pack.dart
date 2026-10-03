class OfflineMapPack {
  final String id;
  final String name;
  final String region;
  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;
  final int estimatedSizeMb;
  final String version;
  final DateTime? downloadedAt;

  const OfflineMapPack({
    required this.id,
    required this.name,
    required this.region,
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
    required this.estimatedSizeMb,
    required this.version,
    this.downloadedAt,
  });

  bool contains(double latitude, double longitude) {
    return latitude >= minLatitude &&
        latitude <= maxLatitude &&
        longitude >= minLongitude &&
        longitude <= maxLongitude;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'region': region,
      'minLatitude': minLatitude,
      'maxLatitude': maxLatitude,
      'minLongitude': minLongitude,
      'maxLongitude': maxLongitude,
      'estimatedSizeMb': estimatedSizeMb,
      'version': version,
      'downloadedAt': downloadedAt?.toIso8601String(),
    };
  }

  factory OfflineMapPack.fromJson(Map<String, dynamic> json) {
    return OfflineMapPack(
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String,
      minLatitude: (json['minLatitude'] as num).toDouble(),
      maxLatitude: (json['maxLatitude'] as num).toDouble(),
      minLongitude: (json['minLongitude'] as num).toDouble(),
      maxLongitude: (json['maxLongitude'] as num).toDouble(),
      estimatedSizeMb: (json['estimatedSizeMb'] as num).toInt(),
      version: json['version'] as String,
      downloadedAt: json['downloadedAt'] == null
          ? null
          : DateTime.parse(json['downloadedAt'] as String),
    );
  }
}
