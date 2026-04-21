/// Utilidad para Geohashing (Base32)
/// Permite codificar coordenadas (lat, lng) a strings y calcular vecinos
/// para consultas espaciales eficientes en Firebase Realtime Database.
class GeoHashUtils {
  static const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Codifica una ubicación (lat, lng) a un geohash de la precisión dada.
  /// Precisión sugerida:
  /// 5 chars ~ 4.9km x 4.9km
  /// 6 chars ~ 1.2km x 0.6km
  /// 7 chars ~ 152m x 152m
  static String encode(double lat, double lon, {int precision = 9}) {
    var idx = 0; // index into base32 map
    var bit = 0; // each char holds 5 bits
    var evenBit = true;
    var geohash = '';

    var latMin = -90.0, latMax = 90.0;
    var lonMin = -180.0, lonMax = 180.0;

    while (geohash.length < precision) {
      if (evenBit) {
        // bisect E-W longitude
        var lonMid = (lonMin + lonMax) / 2;
        if (lon >= lonMid) {
          idx = idx * 2 + 1;
          lonMin = lonMid;
        } else {
          idx = idx * 2;
          lonMax = lonMid;
        }
      } else {
        // bisect N-S latitude
        var latMid = (latMin + latMax) / 2;
        if (lat >= latMid) {
          idx = idx * 2 + 1;
          latMin = latMid;
        } else {
          idx = idx * 2;
          latMax = latMid;
        }
      }
      evenBit = !evenBit;

      if (++bit == 5) {
        // 5 bits gives us a character: append it and start over
        geohash += _base32[idx];
        bit = 0;
        idx = 0;
      }
    }

    return geohash;
  }

  /// Decodifica un geohash a su punto central (lat, lng).
  static (double lat, double lng) decode(String geohash) {
    var evenBit = true;
    var latMin = -90.0, latMax = 90.0;
    var lonMin = -180.0, lonMax = 180.0;

    for (final char in geohash.split('')) {
      final idx = _base32.indexOf(char);
      if (idx == -1) break;
      for (var bits = 4; bits >= 0; bits--) {
        final bitN = (idx >> bits) & 1;
        if (evenBit) {
          final lonMid = (lonMin + lonMax) / 2;
          if (bitN == 1) {
            lonMin = lonMid;
          } else {
            lonMax = lonMid;
          }
        } else {
          final latMid = (latMin + latMax) / 2;
          if (bitN == 1) {
            latMin = latMid;
          } else {
            latMax = latMid;
          }
        }
        evenBit = !evenBit;
      }
    }
    return ((latMin + latMax) / 2, (lonMin + lonMax) / 2);
  }

  /// Obtiene los 8 vecinos + la propia celda de un geohash.
  /// Método: decode → offset en 8 direcciones → re-encode.
  static List<String> getNeighbors(String hash) {
    final precision = hash.length;
    final latStep = 180.0 / (1 << (precision * 5 ~/ 2));
    final lngStep = 360.0 / (1 << ((precision * 5 + 1) ~/ 2));
    final (lat, lng) = decode(hash);

    final offsets = [
      (0.0, 0.0),
      (latStep, 0.0),
      (-latStep, 0.0),
      (0.0, lngStep),
      (0.0, -lngStep),
      (latStep, lngStep),
      (latStep, -lngStep),
      (-latStep, lngStep),
      (-latStep, -lngStep),
    ];

    final neighbors = <String>{};
    for (final (dLat, dLng) in offsets) {
      final nLat = (lat + dLat).clamp(-90.0, 90.0);
      final nLng = (lng + dLng).clamp(-180.0, 180.0);
      neighbors.add(encode(nLat, nLng, precision: precision));
    }
    return neighbors.toList();
  }

  /// [Deprecado] Conservado por compatibilidad. Usar getNeighbors() en su lugar.
  static List<String> neighbors(String geohash) => getNeighbors(geohash);

  /// Obtiene el caracter final par consultas de rango (high bound).
  static String nextHash(String hash) {
    return '$hash~';
  }
}
