import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Qué ajuste del teléfono conviene abrir para solucionar el problema.
enum AccionUbicacion { ninguna, ajustesApp, ajustesUbicacion }

/// Error con un mensaje listo para mostrar al usuario.
class UbicacionException implements Exception {
  UbicacionException(this.mensaje, {this.accion = AccionUbicacion.ninguna});

  final String mensaje;
  final AccionUbicacion accion;

  @override
  String toString() => mensaje;
}

/// Todo lo relacionado con la ubicación del dispositivo (igual que en clase).
class UbicacionService {
  /// Revisa que la ubicación esté encendida y que tengamos permiso.
  Future<void> asegurarPermiso() async {
    final encendida = await Geolocator.isLocationServiceEnabled();
    if (!encendida) {
      throw UbicacionException(
        'La ubicación del dispositivo está apagada. Actívala e intenta de nuevo.',
        accion: AccionUbicacion.ajustesUbicacion,
      );
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      // Aquí Android o iOS muestran la ventana de permiso al usuario
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      throw UbicacionException('No diste permiso para usar tu ubicación.');
    }
    if (permiso == LocationPermission.deniedForever) {
      throw UbicacionException(
        'El permiso de ubicación está bloqueado. Actívalo en los ajustes '
        'de la app, en Ubicación, eligiendo la opción mientras se usa la app.',
        accion: AccionUbicacion.ajustesApp,
      );
    }
  }

  /// Pide la posición UNA vez.
  Future<Position> posicionActual() async {
    await asegurarPermiso();
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  /// Flujo que avisa cada vez que te mueves al menos 5 metros.
  Stream<Position> seguirPosicion() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }

  /// Abre la pantalla de ajustes del teléfono que resuelve el problema.
  Future<void> abrirAjustes(AccionUbicacion accion) async {
    if (accion == AccionUbicacion.ajustesApp) {
      await Geolocator.openAppSettings();
    } else if (accion == AccionUbicacion.ajustesUbicacion) {
      await Geolocator.openLocationSettings();
    }
  }

  /// Distancia en metros entre dos puntos, en línea recta.
  static double distanciaMetros(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }
}

/// Convierte metros a un texto fácil de leer: "350 m" o "2.4 km".
String formatoDistancia(double metros) {
  if (metros < 1000) {
    return '${metros.round()} m';
  }
  return '${(metros / 1000).toStringAsFixed(1)} km';
}
