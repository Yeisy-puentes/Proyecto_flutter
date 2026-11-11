import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Si te alejas más de estos metros de la ruta, se recalcula sola.
const double kDistanciaDesvio = 40;

/// Cómo se hace el domicilio. Cada modo usa un perfil distinto del servidor.
enum ModoViaje {
  carro('En moto o carro', 'routed-car', 8.3), // 8.3 m/s = 30 km/h
  pie('A pie', 'routed-foot', 1.3); // 1.3 m/s = 4.7 km/h

  const ModoViaje(this.etiqueta, this.perfil, this.velocidadRespaldo);

  final String etiqueta;
  final String perfil; // parte de la dirección del servidor
  final double velocidadRespaldo; // para estimar el tiempo del plan B
}

/// Resultado de calcular un recorrido.
class Ruta {
  const Ruta({
    required this.puntos,
    required this.distanciaMetros,
    required this.duracionSegundos,
    required this.porCalles,
    required this.origen,
    required this.destino,
    required this.modo,
  });

  final List<LatLng> puntos; // la línea que se dibuja sobre las calles
  final double distanciaMetros;
  final double duracionSegundos;
  final bool porCalles; // false = línea recta de respaldo
  final LatLng origen; // dónde estabas exactamente
  final LatLng destino; // la casa del cliente exactamente
  final ModoViaje modo;
}

/// Pide el recorrido al servidor público de OSRM de FOSSGIS (OpenStreetMap).
class RutasService {
  static const _servidor = 'https://routing.openstreetmap.de';

  Future<Ruta> calcular(LatLng origen, LatLng destino, ModoViaje modo) async {
    // Formato de OSRM: /perfil/route/v1/driving/LONGITUD,LATITUD;LONGITUD,LATITUD
    // La palabra "driving" la exige el formato; el perfil real lo da modo.perfil.
    final url = Uri.parse(
      '$_servidor/${modo.perfil}/route/v1/driving/'
      '${origen.longitude},${origen.latitude};'
      '${destino.longitude},${destino.latitude}'
      '?overview=full&geometries=geojson&alternatives=false&steps=false',
    );

    try {
      final respuesta =
          await http.get(url).timeout(const Duration(seconds: 12));
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
        final rutas = datos['routes'] as List<dynamic>;
        if (datos['code'] == 'Ok' && rutas.isNotEmpty) {
          final ruta = rutas.first as Map<String, dynamic>;
          final geometria = ruta['geometry'] as Map<String, dynamic>;
          final coordenadas = geometria['coordinates'] as List<dynamic>;
          // GeoJSON entrega cada punto como [longitud, latitud]
          final puntos = coordenadas.map((c) {
            final par = c as List<dynamic>;
            return LatLng(
              (par[1] as num).toDouble(),
              (par[0] as num).toDouble(),
            );
          }).toList();
          if (puntos.length >= 2) {
            return Ruta(
              puntos: puntos,
              distanciaMetros: (ruta['distance'] as num).toDouble(),
              duracionSegundos: (ruta['duration'] as num).toDouble(),
              porCalles: true,
              origen: origen,
              destino: destino,
              modo: modo,
            );
          }
        }
      }
    } catch (_) {
      // Sin internet, servidor ocupado o respuesta inesperada: plan B.
    }

    // Plan B: línea recta con un tiempo estimado según el modo
    final metros =
        const Distance().as(LengthUnit.Meter, origen, destino).toDouble();
    return Ruta(
      puntos: [origen, destino],
      distanciaMetros: metros,
      duracionSegundos: metros / modo.velocidadRespaldo,
      porCalles: false,
      origen: origen,
      destino: destino,
      modo: modo,
    );
  }
}

/// Distancia en metros desde un punto hasta la línea de la ruta
/// (al tramo más cercano, no solo a sus vértices).
double distanciaARuta(LatLng punto, List<LatLng> ruta) {
  if (ruta.length < 2) {
    return double.infinity;
  }
  var minima = double.infinity;
  for (var i = 0; i < ruta.length - 1; i++) {
    final d = _distanciaATramo(punto, ruta[i], ruta[i + 1]);
    if (d < minima) {
      minima = d;
    }
  }
  return minima;
}

/// Proyecta los puntos en un plano local (en metros) alrededor de p.
/// Es suficientemente exacto para distancias de pocos kilómetros.
double _distanciaATramo(LatLng p, LatLng a, LatLng b) {
  const radioTierra = 6371000.0;
  final cosLat = math.cos(p.latitude * math.pi / 180);
  double x(LatLng q) =>
      (q.longitude - p.longitude) * math.pi / 180 * radioTierra * cosLat;
  double y(LatLng q) => (q.latitude - p.latitude) * math.pi / 180 * radioTierra;

  final ax = x(a);
  final ay = y(a);
  final dx = x(b) - ax;
  final dy = y(b) - ay;
  final largo2 = dx * dx + dy * dy;
  // t indica en qué parte del tramo está el punto más cercano (0 = a, 1 = b)
  final t = largo2 == 0
      ? 0.0
      : (-(ax * dx + ay * dy) / largo2).clamp(0.0, 1.0).toDouble();
  final cx = ax + t * dx;
  final cy = ay + t * dy;
  return math.sqrt(cx * cx + cy * cy);
}

/// Convierte segundos a "8 min" o "1 h 15 min".
String formatoDuracion(double segundos) {
  final minutos = (segundos / 60).ceil();
  if (minutos < 60) {
    return '$minutos min';
  }
  return '${minutos ~/ 60} h ${minutos % 60} min';
}
