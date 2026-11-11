import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/mapa_config.dart';
import '../models/arreglo.dart';
import '../models/catalogos.dart';
import '../models/cliente.dart';
import '../services/geocodificacion_service.dart';
import '../services/rutas_service.dart';
import '../services/ubicacion_service.dart';
import '../state/datos.dart';
import '../theme/app_theme.dart';
import '../utils/formatos.dart';
import '../widgets/formularios.dart';
import '../widgets/ui.dart';

/// Un domicilio = arreglo sin entregar, para domicilio, cuyo cliente
/// tiene la casa marcada en el mapa.
class Domicilio {
  const Domicilio(this.arreglo, this.cliente);

  final Arreglo arreglo;
  final Cliente cliente;

  LatLng get punto => cliente.ubicacion!;
}

/// NUEVO en la app móvil. Lo mismo del taller de clase (mapa OpenStreetMap,
/// ubicación en tiempo real, puntos guardados en Firestore y Cómo llegar)
/// aplicado a las entregas a domicilio de Interfajas.
class DomiciliosScreen extends StatefulWidget {
  const DomiciliosScreen({super.key});

  @override
  State<DomiciliosScreen> createState() => _DomiciliosScreenState();
}

class _DomiciliosScreenState extends State<DomiciliosScreen> {
  final _mapa = MapController();
  final _ubicacion = UbicacionService();
  final _rutas = RutasService();

  StreamSubscription<Position>? _subPosicion;
  LatLng? _yo;
  double _precision = 0;
  bool _buscando = false;

  String? _idDestino;
  Ruta? _ruta;
  bool _calculando = false;
  bool _llego = false;
  ModoViaje _modo = ModoViaje.carro;
  DateTime _ultimoCalculo = DateTime(2000);

  @override
  void dispose() {
    _subPosicion?.cancel();
    super.dispose();
  }

  DatosApp get _datos => DatosScope.read(context);

  List<Domicilio> _pendientes(DatosApp datos) {
    final lista = <Domicilio>[];
    for (final a in datos.arreglos) {
      final c = datos.cliente(a.idCliente);
      if (a.domicilio && !a.entregado && c?.ubicacion != null) lista.add(Domicilio(a, c!));
    }
    lista.sort((a, b) => (a.arreglo.fechaEntrega ?? '9999').compareTo(b.arreglo.fechaEntrega ?? '9999'));
    return lista;
  }

  int _sinUbicacion(DatosApp datos) => datos.arreglos
      .where((a) => a.domicilio && !a.entregado && datos.cliente(a.idCliente)?.ubicacion == null)
      .length;

  Domicilio? _destino(DatosApp datos) {
    for (final d in _pendientes(datos)) {
      if (d.arreglo.id == _idDestino) return d;
    }
    return null;
  }

  void _mensaje(String texto, {bool error = true}) {
    if (mounted) toast(context, texto, error: error);
  }

  // ---------- Ubicación (igual que en clase) ----------
  Future<void> _activarUbicacion() async {
    setState(() => _buscando = true);
    try {
      final posicion = await _ubicacion.posicionActual();
      if (!mounted) return;
      _actualizarPosicion(posicion);
      _mapa.move(_yo!, 17);
      _subPosicion ??= _ubicacion.seguirPosicion().listen(
        _actualizarPosicion,
        onError: (Object e) => _mensaje('Se perdió la ubicación: $e'),
      );
    } on UbicacionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.mensaje),
          backgroundColor: AppColors.red600,
          duration: const Duration(seconds: 8),
          action: e.accion == AccionUbicacion.ninguna
              ? null
              : SnackBarAction(
                  label: 'Abrir ajustes',
                  textColor: Colors.white,
                  onPressed: () => _ubicacion.abrirAjustes(e.accion),
                ),
        ),
      );
    } on TimeoutException {
      _mensaje('No llegó la ubicación. En el simulador fija una ubicación; en el teléfono acércate a una ventana.');
    } catch (e) {
      _mensaje('No se pudo obtener la ubicación: $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _actualizarPosicion(Position posicion) {
    if (!mounted) return;
    setState(() {
      _yo = LatLng(posicion.latitude, posicion.longitude);
      _precision = posicion.accuracy;
    });
    _revisarLlegada();
    _revisarDesvio();
  }

  void _botonUbicacion() {
    final yo = _yo;
    if (yo != null) {
      _mapa.move(yo, 17);
    } else {
      _activarUbicacion();
    }
  }

  // ---------- Taller ----------
  void _menuPunto(LatLng punto) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${punto.latitude.toStringAsFixed(5)}, ${punto.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: AppColors.slate500),
            ),
            const SizedBox(height: 12),
            Btn(
              texto: 'Fijar la empresa aquí',
              icono: Icons.storefront,
              tipo: BtnTipo.navy,
              onPressed: () {
                Navigator.pop(ctx);
                _datos.repo.fijarTaller(punto);
                _mensaje('Ubicación de la empresa guardada', error: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Detalle de la empresa en el mapa
  void _verEmpresa(DatosApp datos) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: const Center(child: LogoInterfajas(alto: 56)),
              ),
              const SizedBox(height: 12),
              Text(
                datos.tallerDireccion.isEmpty
                    ? (datos.taller == null ? 'Aún no has registrado la dirección de la empresa.' : 'Ubicación marcada en el mapa')
                    : '${datos.tallerDireccion} · ${datos.tallerCiudad}',
                style: const TextStyle(color: AppColors.slate700, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Btn(
                texto: datos.tallerDireccion.isEmpty ? 'Registrar dirección de la empresa' : 'Cambiar dirección',
                icono: Icons.edit_location_alt_outlined,
                tipo: BtnTipo.navy,
                full: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _direccionEmpresa(datos);
                },
              ),
              const SizedBox(height: 4),
              const Text(
                'También puedes mantener presionado el mapa para fijar el punto exacto.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.slate400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Escribe la dirección de la empresa y la ubica sola en el mapa
  Future<void> _direccionEmpresa(DatosApp datos) async {
    final dir = TextEditingController(text: datos.tallerDireccion);
    final ciudad = TextEditingController(text: datos.tallerCiudad);
    final ok = await mostrarModal<bool>(
      context,
      titulo: 'Dirección de la empresa',
      subtitulo: 'Se marcará en el mapa de Domicilios',
      icono: Icons.storefront,
      cuerpo: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Campo(
            label: 'Dirección',
            child: TextField(controller: dir, decoration: const InputDecoration(hintText: 'Cra 5 # 12-34, barrio Centro')),
          ),
          const SizedBox(height: 16),
          Campo(label: 'Ciudad / municipio', child: TextField(controller: ciudad)),
          const SizedBox(height: 8),
          PieModal(textoAccion: 'Guardar', tipo: BtnTipo.navy, onAccion: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    final texto = dir.text.trim();
    final c = ciudad.text.trim().isEmpty ? 'Neiva' : ciudad.text.trim();
    if (ok != true || texto.isEmpty) return;
    _mensaje('Buscando la dirección en el mapa...', error: false);
    final punto = await GeocodificacionService().buscar(texto, c);
    if (!mounted) return;
    if (punto == null) {
      _mensaje('No se encontró "$texto". Mantén presionado el mapa sobre la empresa para fijarla a mano.');
      return;
    }
    datos.repo.fijarTaller(punto, direccion: texto, ciudad: c);
    _mapa.move(punto, 17);
    _mensaje('Empresa ubicada en el mapa. Si el punto no es exacto, mantén presionado el lugar correcto.', error: false);
  }

  // ---------- Domicilios ----------
  void _verDomicilio(Domicilio d) {
    final yo = _yo;
    final distancia = yo == null ? null : UbicacionService.distanciaMetros(yo, d.punto);
    final a = d.arreglo;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(a.codigo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 18)),
                  const SizedBox(width: 8),
                  StatusBadge(estado: a.estado),
                ],
              ),
              const SizedBox(height: 4),
              Text(d.cliente.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.slate800)),
              const SizedBox(height: 8),
              _linea(Icons.phone_outlined, d.cliente.telefono),
              if (d.cliente.direccion.isNotEmpty) _linea(Icons.place_outlined, d.cliente.direccion),
              _linea(Icons.content_cut, a.descripcion),
              if (a.fechaEntrega != null)
                _linea(Icons.event, '${fechaKey(a.fechaEntrega)}${a.horaEntrega != null ? ', ${time12(a.horaEntrega)}' : ''}'),
              if (distancia != null) _linea(Icons.near_me_outlined, 'A ${formatoDistancia(distancia)} de ti en línea recta'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: a.saldo > 0 ? AppColors.orange50 : AppColors.green50,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  a.saldo > 0 ? 'Cobrar al entregar: ${cop(a.saldo)}' : 'Ya está pagado',
                  style: TextStyle(fontWeight: FontWeight.bold, color: a.saldo > 0 ? AppColors.orange700 : AppColors.green700),
                ),
              ),
              const SizedBox(height: 16),
              Btn(
                texto: 'Cómo llegar',
                icono: Icons.directions,
                full: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _irA(d);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linea(IconData icono, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 16, color: AppColors.slate400),
            const SizedBox(width: 8),
            Expanded(child: Text(texto, style: const TextStyle(color: AppColors.slate600))),
          ],
        ),
      );

  void _verLista(List<Domicilio> lista) {
    final yo = _yo;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                'Domicilios pendientes (${lista.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
            ),
            if (lista.isEmpty) const Vacio(texto: 'No hay domicilios pendientes.'),
            for (final d in lista)
              ListTile(
                leading: Icon(Icons.location_on, color: d.arreglo.estado.punto),
                title: Text(d.cliente.nombre),
                subtitle: Text('${d.arreglo.codigo} · ${d.arreglo.estado.etiqueta} · ${fechaKey(d.arreglo.fechaEntrega, 'd MMM')}'),
                trailing: yo == null ? null : Text(formatoDistancia(UbicacionService.distanciaMetros(yo, d.punto))),
                onTap: () {
                  Navigator.pop(ctx);
                  _mapa.move(d.punto, 17);
                  _verDomicilio(d);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ---------- Cómo llegar (igual que en clase) ----------
  Future<void> _irA(Domicilio d, {bool encuadrar = true}) async {
    if (_yo == null) {
      await _activarUbicacion();
      if (_yo == null) return;
    }
    if (!mounted) return;
    final mismo = _idDestino == d.arreglo.id;
    setState(() {
      _idDestino = d.arreglo.id;
      if (!mismo) _ruta = null;
      _calculando = true;
      _llego = false;
    });
    _ultimoCalculo = DateTime.now();

    final ruta = await _rutas.calcular(_yo!, d.punto, _modo);
    if (!mounted || _idDestino != d.arreglo.id) return;
    setState(() {
      _ruta = ruta;
      _calculando = false;
    });
    if (encuadrar) {
      _mapa.fitCamera(
        CameraFit.coordinates(
          coordinates: [ruta.origen, ...ruta.puntos, ruta.destino],
          padding: const EdgeInsets.fromLTRB(40, 260, 40, 90),
          maxZoom: 18,
        ),
      );
    }
    if (!ruta.porCalles) _mensaje('No se pudo trazar por calles: se muestra la línea recta.');
    _revisarLlegada();
  }

  void _revisarDesvio() {
    final yo = _yo;
    final ruta = _ruta;
    final destino = _destino(_datos);
    if (yo == null || ruta == null || destino == null) return;
    if (_calculando || _llego || !ruta.porCalles) return;
    final fuera = distanciaARuta(yo, ruta.puntos) > kDistanciaDesvio;
    final puede = DateTime.now().difference(_ultimoCalculo).inSeconds >= 15;
    if (fuera && puede) {
      _mensaje('Te saliste de la ruta: recalculando…', error: false);
      _irA(destino, encuadrar: false);
    }
  }

  void _revisarLlegada() {
    final yo = _yo;
    final destino = _destino(_datos);
    if (yo == null || destino == null || _llego) return;
    if (UbicacionService.distanciaMetros(yo, destino.punto) <= kRadioLlegada) {
      setState(() => _llego = true);
      _mensaje('¡Llegaste donde ${destino.cliente.nombre}!', error: false);
    }
  }

  /// Al llegar: se marca como entregado (si debe, primero pregunta, como en la web)
  Future<void> _entregar(Domicilio d) async {
    final a = d.arreglo;
    if (a.saldo > 0) {
      final ok = await confirmar(
        context,
        titulo: 'Arreglo con saldo pendiente',
        mensaje: '${a.codigo} aún debe ${cop(a.saldo)}. Registra el pago antes, o márcalo como entregado de todas formas.',
        confirmar: 'Entregar igual',
        peligro: false,
      );
      if (!ok) return;
    }
    _datos.repo.cambiarEstado(a.id, EstadoArreglo.entregado);
    _terminar();
    _mensaje('${a.codigo} de ${d.cliente.nombre} entregado.', error: false);
  }

  bool _ubicando = false;

  /// Ubica por su dirección a los clientes con domicilio que aún no tienen punto en el mapa
  Future<void> _ubicarTodos(DatosApp datos) async {
    final ids = {
      for (final a in datos.arreglos)
        if (a.domicilio && !a.entregado) a.idCliente,
    };
    final clientes = [
      for (final id in ids)
        if (datos.cliente(id) case final c? when c.ubicacion == null && c.direccion.isNotEmpty) c,
    ];
    if (clientes.isEmpty) {
      _mensaje('Esos clientes no tienen dirección escrita. Agrégala en Clientes → Editar.');
      return;
    }
    setState(() => _ubicando = true);
    final mensajero = ScaffoldMessenger.of(context);
    var ok = 0;
    for (final c in clientes) {
      if (await ubicarPorDireccion(datos, c.id, c.direccion, c.ciudad, mensajero)) ok++;
    }
    if (mounted) setState(() => _ubicando = false);
    _mensaje('Se ubicaron $ok de ${clientes.length} casas por su dirección.', error: ok == 0);
  }

  void _terminar() => setState(() {
        _idDestino = null;
        _ruta = null;
        _calculando = false;
        _llego = false;
      });

  // ---------- Pantalla ----------
  @override
  Widget build(BuildContext context) {
    final datos = DatosScope.of(context);
    final yo = _yo;
    final pendientes = _pendientes(datos);
    final destino = _destino(datos);
    final ruta = destino == null ? null : _ruta;
    final taller = datos.taller ?? kTallerPorDefecto;

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapa,
          options: MapOptions(
            initialCenter: kCentroInicial,
            initialZoom: kZoomInicial,
            onLongPress: (_, punto) => _menuPunto(punto),
          ),
          children: [
            TileLayer(urlTemplate: kUrlTeselas, userAgentPackageName: kPaqueteApp),
            if (ruta != null)
              PolylineLayer(
                polylines: [
                  if (ruta.porCalles) ...[
                    Polyline(points: [ruta.origen, ruta.puntos.first], strokeWidth: 3, color: Colors.grey.shade600),
                    Polyline(points: [ruta.puntos.last, ruta.destino], strokeWidth: 3, color: Colors.grey.shade600),
                  ],
                  Polyline(points: ruta.puntos, strokeWidth: 6, color: ruta.porCalles ? AppColors.blue : AppColors.orange500),
                ],
              ),
            if (yo != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: yo,
                    radius: _precision,
                    useRadiusInMeter: true,
                    color: const Color(0x331565C0),
                    borderColor: const Color(0x881565C0),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                // La empresa: círculo navy + etiqueta "Interfajas"
                Marker(
                  point: taller,
                  width: 110,
                  height: 66,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => _verEmpresa(datos),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: AppShadows.md,
                          ),
                          child: const Text(
                            'Interfajas',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.cyan,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: AppShadows.md,
                          ),
                          child: const Icon(Icons.storefront, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
                for (final d in pendientes)
                  Marker(
                    point: d.punto,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _verDomicilio(d),
                      child: Icon(
                        Icons.location_on,
                        size: 44,
                        color: d.arreglo.estado.punto,
                        shadows: const [Shadow(blurRadius: 4, color: Colors.black38)],
                      ),
                    ),
                  ),
                if (yo != null)
                  Marker(
                    point: yo,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: destino == null ? _panelInfo(datos, yo, pendientes.length) : _panelRuta(destino, ruta),
        ),
        Positioned(
          right: 12,
          bottom: 24,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _fab('fab-lista', Icons.list_alt, () => _verLista(pendientes), badge: pendientes.length),
                const SizedBox(height: 12),
                _fab('fab-taller', Icons.storefront, () => _mapa.move(taller, 16)),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'fab-yo',
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  onPressed: _buscando ? null : _botonUbicacion,
                  child: _buscando
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fab(String tag, IconData icono, VoidCallback onTap, {int badge = 0}) => FloatingActionButton.small(
        heroTag: tag,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.navy,
        onPressed: onTap,
        child: Badge(label: Text('$badge'), isLabelVisible: badge > 0, child: Icon(icono)),
      );

  Widget _panelInfo(DatosApp datos, LatLng? yo, int cantidad) {
    final sin = _sinUbicacion(datos);
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: const Icon(Icons.delivery_dining, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$cantidad ${cantidad == 1 ? 'domicilio pendiente' : 'domicilios pendientes'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800),
                ),
                Text(
                  yo == null
                      ? 'Toca el botón de ubicación para encontrarte'
                      : 'Estás en ${yo.latitude.toStringAsFixed(5)}, ${yo.longitude.toStringAsFixed(5)} (± ${_precision.round()} m)',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                if (sin > 0)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$sin sin ubicar en el mapa',
                          style: const TextStyle(fontSize: 12, color: AppColors.orange700),
                        ),
                      ),
                      _ubicando
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () => _ubicarTodos(datos),
                              child: const Text('Ubicar por dirección', style: TextStyle(fontSize: 12)),
                            ),
                    ],
                  ),
                if (datos.taller == null)
                  GestureDetector(
                    onTap: () => _direccionEmpresa(datos),
                    child: const Text(
                      'Registra la dirección de la empresa →',
                      style: TextStyle(fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelRuta(Domicilio destino, Ruta? ruta) {
    final yo = _yo;
    final faltan = yo == null ? null : UbicacionService.distanciaMetros(yo, destino.punto);
    final a = destino.arreglo;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delivery_dining, color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hacia ${destino.cliente.nombre}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate800),
                ),
              ),
              IconButton(tooltip: 'Terminar', icon: const Icon(Icons.close), onPressed: _terminar),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 6),
            child: SegmentedButton<ModoViaje>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: ModoViaje.carro, icon: Icon(Icons.two_wheeler), label: Text('Moto / carro')),
                ButtonSegment(value: ModoViaje.pie, icon: Icon(Icons.directions_walk), label: Text('A pie')),
              ],
              selected: {_modo},
              onSelectionChanged: _calculando
                  ? null
                  : (s) {
                      setState(() => _modo = s.first);
                      _irA(destino);
                    },
            ),
          ),
          if (_calculando)
            const Padding(padding: EdgeInsets.only(right: 8, bottom: 8), child: LinearProgressIndicator())
          else if (ruta != null)
            Text(
              '${ruta.porCalles ? ruta.modo.etiqueta : 'Línea recta'}: ${formatoDistancia(ruta.distanciaMetros)} · ${formatoDuracion(ruta.duracionSegundos)}',
              style: const TextStyle(color: AppColors.slate700),
            ),
          if (faltan != null)
            Text(
              _llego ? '¡Llegaste!' : 'Te faltan ${formatoDistancia(faltan)} en línea recta',
              style: TextStyle(fontWeight: FontWeight.w600, color: _llego ? AppColors.green600 : AppColors.slate500),
            ),
          if (a.saldo > 0)
            Text('Cobrar: ${cop(a.saldo)}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.orange700)),
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _calculando ? null : () => _irA(destino),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Recalcular'),
                ),
                const Spacer(),
                if (a.saldo > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Btn(texto: 'Cobrar', sm: true, tipo: BtnTipo.outline, onPressed: () => mostrarRegistrarPago(context, a)),
                  ),
                Btn(
                  texto: 'Entregado',
                  icono: Icons.done_all,
                  sm: true,
                  tipo: _llego ? BtnTipo.green : BtnTipo.navy,
                  onPressed: () => _entregar(destino),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
