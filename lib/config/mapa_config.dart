import 'package:latlong2/latlong.dart';

/// Configuración general del mapa (igual que en la clase).
/// Punto inicial: centro de Neiva (aproximado).
const LatLng kCentroInicial = LatLng(2.9273, -75.2819);
const double kZoomInicial = 13;

/// Ubicación del taller mientras no la fijes en el mapa
/// (mantén presionado el mapa → "Fijar taller aquí").
const LatLng kTallerPorDefecto = LatLng(2.9273, -75.2819);

/// Teselas (imágenes del mapa) de OpenStreetMap: gratis y sin API key.
const String kUrlTeselas = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Identifica tu app ante OpenStreetMap (lo exige su política de uso).
const String kPaqueteApp = 'co.interfajas.app';

/// A cuántos metros de la casa del cliente consideramos que ya llegaste.
const double kRadioLlegada = 25;
