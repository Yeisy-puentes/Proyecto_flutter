import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Convierte una dirección escrita en un punto del mapa (geocodificación)
/// con Nominatim, el buscador gratuito de OpenStreetMap (sin API key).
///
/// Las direcciones colombianas ("Cra 5 # 12-34") no siempre existen
/// número por número en OpenStreetMap: si no encuentra la casa exacta,
/// prueba con la calle y por último con el barrio. Por eso el punto
/// queda marcado como "aproximado" y se puede ajustar en el mapa.
class GeocodificacionService {
  static const _servidor = 'https://nominatim.openstreetmap.org/search';

  /// Zona de Neiva y Rivera (Huila): oeste, norte, este, sur
  static const _zona = '-75.45,3.05,-75.10,2.65';

  /// Devuelve el punto, o null si no lo encontró o no hay internet.
  Future<LatLng?> buscar(String direccion, String ciudad) async {
    final dir = _normalizar(direccion);
    if (dir.isEmpty) return null;
    final lugar = ciudad.trim().isEmpty ? 'Neiva' : ciudad.trim();

    // De lo más preciso a lo más general
    final intentos = <String>{
      '$dir, $lugar, Huila, Colombia',
      if (_soloVia(dir) != dir) '${_soloVia(dir)}, $lugar, Huila, Colombia',
      if (_barrio(direccion) != null) '${_barrio(direccion)}, $lugar, Huila, Colombia',
    };

    for (final q in intentos) {
      final p = await _consultar(q);
      if (p != null) return p;
      // Nominatim pide máximo 1 consulta por segundo
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    }
    return null;
  }

  Future<LatLng?> _consultar(String q) async {
    final url = Uri.parse(_servidor).replace(queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'limit': '1',
      'countrycodes': 'co',
      'viewbox': _zona,
      'accept-language': 'es',
    });
    try {
      final r = await http.get(url, headers: {
        // Nominatim exige identificar la app
        'User-Agent': 'InterfajasApp/1.0 (co.interfajas.app)',
      }).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final lista = jsonDecode(r.body) as List<dynamic>;
      if (lista.isEmpty) return null;
      final d = lista.first as Map<String, dynamic>;
      return LatLng(double.parse(d['lat'] as String), double.parse(d['lon'] as String));
    } catch (_) {
      return null; // sin internet o servidor ocupado
    }
  }

  /// "Cra 5 # 12-34 barrio Centro" -> "Carrera 5 12-34"
  static String _normalizar(String s) {
    var t = ' ${s.trim()} ';
    final abreviaturas = {
      r'\b(cl|cll|clle)\.?\s': 'Calle ',
      r'\b(cr|cra|kra|kr|crr|carr)\.?\s': 'Carrera ',
      r'\b(av|avda)\.?\s': 'Avenida ',
      r'\b(dg|diag)\.?\s': 'Diagonal ',
      r'\b(tv|trans|tr)\.?\s': 'Transversal ',
    };
    abreviaturas.forEach((patron, valor) {
      t = t.replaceAll(RegExp(patron, caseSensitive: false), valor);
    });
    t = t.replaceAll(RegExp(r'(#|n[°ºo]\.?|no\.)', caseSensitive: false), ' ');
    // Quita "barrio X", "apto 2", "casa 3" (confunden al buscador)
    t = t.replaceAll(RegExp(r'\b(barrio|br|apto|apartamento|casa|piso|torre)\b.*$', caseSensitive: false), '');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// "Carrera 5 12-34" -> "Carrera 5"
  static String _soloVia(String dir) {
    final m = RegExp(r'^((?:Calle|Carrera|Avenida|Diagonal|Transversal)\s+\d+\s?[A-Za-z]?)', caseSensitive: false)
        .firstMatch(dir);
    return m?.group(1) ?? dir;
  }

  /// "... barrio Las Granjas" -> "Las Granjas"
  static String? _barrio(String s) {
    final m = RegExp(r'\b(?:barrio|br)\.?\s+([^,#]+)', caseSensitive: false).firstMatch(s);
    return m?.group(1)?.trim();
  }
}
