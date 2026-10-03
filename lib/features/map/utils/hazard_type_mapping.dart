import '../../../core/models/hazard_type.dart';
import '../models/hazard.dart';

HazardType hazardTypeForReport(String value) {
  switch (canonicalHazardTypeName(value)) {
    case 'OPEN MANHOLE':
      return HazardType.openManhole;
    case 'FLOODED ROAD':
      return HazardType.floodedRoad;
    case 'FALLEN TREE':
      return HazardType.fallenTree;
    case 'ELECTRIC HAZARD':
      return HazardType.electricHazard;
    case 'DAMAGED ROAD':
      return HazardType.damagedRoad;
    case 'WATER LOGGING':
      return HazardType.waterLogging;
    default:
      return HazardType.other;
  }
}