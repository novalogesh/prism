String canonicalHazardTypeName(String value) {
  switch (value.trim().toUpperCase()) {
    case 'FLOOD':
    case 'FLOODED ROAD':
      return 'FLOODED ROAD';
    case 'ELECTRICAL':
    case 'ELECTRIC HAZARD':
      return 'ELECTRIC HAZARD';
    case 'WATERLOGGING':
    case 'WATER LOGGING':
      return 'WATER LOGGING';
    default:
      return value.trim().toUpperCase();
  }
}