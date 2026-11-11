import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/mapa_config.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Mapa para elegir la casa del cliente: mueve el mapa hasta que el pin
/// del centro quede sobre la casa y toca "Usar este punto".
class SeleccionarUbicacionScreen extends StatefulWidget {
  const SeleccionarUbicacionScreen({super.key, this.inicial, this.titulo = 'Marcar la casa del cliente'});

  final LatLng? inicial;
  final String titulo;

  @override
  State<SeleccionarUbicacionScreen> createState() => _SeleccionarUbicacionScreenState();
}

class _SeleccionarUbicacionScreenState extends State<SeleccionarUbicacionScreen> {
  final _mapa = MapController();
  final _ubicacion = UbicacionService();
  bool _buscando = false;

  /// Útil cuando estás en la casa del cliente: usa el GPS.
  Future<void> _irAMiUbicacion() async {
    setState(() => _buscando = true);
    try {
      final p = await _ubicacion.posicionActual();
      _mapa.move(LatLng(p.latitude, p.longitude), 18);
    } on UbicacionException catch (e) {
      if (mounted) toast(context, e.mensaje, error: true);
    } on TimeoutException {
      if (mounted) toast(context, 'No llegó la ubicación. Intenta de nuevo.', error: true);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: widget.inicial ?? kCentroInicial,
              initialZoom: widget.inicial == null ? kZoomInicial : 17,
            ),
            children: [
              TileLayer(urlTemplate: kUrlTeselas, userAgentPackageName: kPaqueteApp),
              RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
            ],
          ),
          // Pin fijo en el centro: la punta señala el punto elegido
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: Icon(Icons.location_on, size: 48, color: AppColors.blue),
              ),
            ),
          ),
          const Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: AppCard(
              padding: EdgeInsets.all(12),
              child: Text(
                'Mueve el mapa hasta que el pin quede sobre la casa. Si estás allí, usa el botón de ubicación.',
                style: TextStyle(color: AppColors.slate700),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'fab-gps-cliente',
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.blue,
              onPressed: _buscando ? null : _irAMiUbicacion,
              child: _buscando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: SizedBox(
                height: 52,
                child: Btn(
                  texto: 'Usar este punto',
                  icono: Icons.check,
                  tipo: BtnTipo.navy,
                  onPressed: () => Navigator.of(context).pop(_mapa.camera.center),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
