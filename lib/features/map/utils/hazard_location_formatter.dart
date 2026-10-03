String formatHazardLocation(double? latitude, double? longitude) {
  if (latitude == null ||
      longitude == null ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    return 'Location unavailable';
  }

  return '${latitude.toStringAsFixed(6)}, '
      '${longitude.toStringAsFixed(6)}';
}