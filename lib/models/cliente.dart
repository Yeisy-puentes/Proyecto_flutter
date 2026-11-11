import 'package:latlong2/latlong.dart';

/// Tabla `clientes` (mismos campos que la web) + ubicación para domicilios.
class Cliente {
  const Cliente({
    required this.id,
    required this.numero,
    required this.nombre,
    required this.cedula,
    required this.telefono,
    this.correo = '',
    this.direccion = '',
    this.ciudad = 'Neiva',
    this.ubicacion,
    this.ubicacionAproximada = false,
  });

  final String id; // id del documento en Firestore
  final int numero; // "Cliente ID: 12" como en la web
  final String nombre;
  final String cedula;
  final String telefono;
  final String correo;
  final String direccion;
  final String ciudad; // municipio (para ubicar la dirección en el mapa)
  final LatLng? ubicacion; // casa en el mapa (opcional)
  /// true = el punto salió de la dirección escrita (puede no ser exacto)
  final bool ubicacionAproximada;

  Map<String, dynamic> toMap() => {
        'numero': numero,
        'nombre': nombre,
        'cedula': cedula,
        'telefono': telefono,
        'correo': correo,
        'direccion': direccion,
        'ciudad': ciudad,
        'ubicacionAproximada': ubicacionAproximada,
        'lat': ubicacion?.latitude,
        'lng': ubicacion?.longitude,
      };

  factory Cliente.fromMap(String id, Map<String, dynamic> d) {
    final lat = d['lat'] as num?;
    final lng = d['lng'] as num?;
    return Cliente(
      id: id,
      numero: (d['numero'] as num? ?? 0).toInt(),
      nombre: d['nombre'] as String? ?? '',
      cedula: d['cedula'] as String? ?? '',
      telefono: d['telefono'] as String? ?? '',
      correo: d['correo'] as String? ?? '',
      direccion: d['direccion'] as String? ?? '',
      ciudad: d['ciudad'] as String? ?? 'Neiva',
      ubicacionAproximada: d['ubicacionAproximada'] as bool? ?? false,
      ubicacion: lat == null || lng == null ? null : LatLng(lat.toDouble(), lng.toDouble()),
    );
  }

  Cliente copyWith({LatLng? ubicacion, bool? ubicacionAproximada}) => Cliente(
        id: id,
        numero: numero,
        nombre: nombre,
        cedula: cedula,
        telefono: telefono,
        correo: correo,
        direccion: direccion,
        ciudad: ciudad,
        ubicacion: ubicacion ?? this.ubicacion,
        ubicacionAproximada: ubicacionAproximada ?? this.ubicacionAproximada,
      );

  String get inicial => nombre.isEmpty ? '?' : nombre[0].toUpperCase();
}
