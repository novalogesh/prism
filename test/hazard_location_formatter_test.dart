import 'package:flutter_test/flutter_test.dart';
import 'package:prism/features/map/utils/hazard_location_formatter.dart';

void main() {
  test('formats a valid coordinate pair', () {
    expect(
      formatHazardLocation(13.0827, 80.2707),
      '13.082700, 80.270700',
    );
  });

  test('shows unavailable when both coordinates are missing', () {
    expect(formatHazardLocation(null, null), 'Location unavailable');
  });

  test('shows unavailable when only one coordinate is present', () {
    expect(formatHazardLocation(13.0827, null), 'Location unavailable');
    expect(formatHazardLocation(null, 80.2707), 'Location unavailable');
  });

  test('shows unavailable for invalid coordinates', () {
    expect(formatHazardLocation(double.nan, 80.2707), 'Location unavailable');
    expect(formatHazardLocation(91, 80.2707), 'Location unavailable');
    expect(formatHazardLocation(13.0827, 181), 'Location unavailable');
  });
}