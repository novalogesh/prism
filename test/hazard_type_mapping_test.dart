import 'package:flutter_test/flutter_test.dart';
import 'package:prism/core/models/hazard_type.dart';
import 'package:prism/features/map/models/hazard.dart';
import 'package:prism/features/map/utils/hazard_type_mapping.dart';

void main() {
  test('current and legacy flood labels map to flooded road', () {
    expect(canonicalHazardTypeName('FLOOD'), 'FLOODED ROAD');
    expect(hazardTypeForReport('FLOOD'), HazardType.floodedRoad);
    expect(hazardTypeForReport('FLOODED ROAD'), HazardType.floodedRoad);
  });

  test('current and legacy electrical labels map to electric hazard', () {
    expect(canonicalHazardTypeName('ELECTRICAL'), 'ELECTRIC HAZARD');
    expect(hazardTypeForReport('ELECTRICAL'), HazardType.electricHazard);
    expect(hazardTypeForReport('ELECTRIC HAZARD'), HazardType.electricHazard);
  });

  test('known canonical labels map to their existing map types', () {
    expect(hazardTypeForReport('OPEN MANHOLE'), HazardType.openManhole);
    expect(hazardTypeForReport('DAMAGED ROAD'), HazardType.damagedRoad);
    expect(hazardTypeForReport('FALLEN TREE'), HazardType.fallenTree);
    expect(hazardTypeForReport('WATER LOGGING'), HazardType.waterLogging);
    expect(hazardTypeForReport('OTHER'), HazardType.other);
  });
}