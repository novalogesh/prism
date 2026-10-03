enum WeatherDataStatus {
  live,
  cached,
  unavailable,
}

class WeatherForecast {
  final String location;
  final double temperature;
  final int rainProbability;
  final double rainfallMm;
  final double windKmh;
  final int humidity;
  final DateTime updatedAt;
  final WeatherDataStatus status;

  const WeatherForecast({
    required this.location,
    required this.temperature,
    required this.rainProbability,
    required this.rainfallMm,
    required this.windKmh,
    required this.humidity,
    required this.updatedAt,
    required this.status,
  });
}
