import '../../../utils/constantes_interoperabilidad.dart';

class SafeUtils {
  static String safeString(Object? value, [String defaultValue = '']) =>
      value?.toString() ?? defaultValue;

  static double safeDouble(Object? value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  static int safeInt(Object? value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static Map<String, dynamic> safeMap(Object? value) {
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (e) {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }
}

extension LocationUtils on Map<String, dynamic> {
  Map<String, dynamic> get normalizedLocation {
    return {
      ...this,
      'lat': this['lat'] ?? this[ConstantesInteroperabilidad.campoLat],
      'lng': this['lng'] ?? this[ConstantesInteroperabilidad.campoLng],
    };
  }
}
