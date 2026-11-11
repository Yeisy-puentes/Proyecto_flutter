import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/arreglo.dart';
import '../models/catalogos.dart';
import '../models/cliente.dart';
import '../models/pago.dart';
import '../state/datos.dart';
import '../theme/app_theme.dart';
import '../utils/formatos.dart';
import '../widgets/formularios.dart';
import '../widgets/ui.dart';
import 'seleccionar_ubicacion_screen.dart';

/// "Detalle del Cliente" de la web: encabezado azul, contacto, saldo pendiente
/// e historial de arreglos con filtros; al tocar un arreglo se despliega para
/// registrar pago y marcar como entregado.
class ClienteDetalleScreen extends StatefulWidget {
  const ClienteDetalleScreen({super.key, required this.idCliente, this.arregloAbierto});

  final String idCliente;
  final String? arregloAbierto;

  @override
  State<ClienteDetalleScreen> createState() => _ClienteDetalleScreenState();
}

class _ClienteDetalleScreenState extends State<ClienteDetalleScreen> {
  final _buscarId = TextEditingController();
  EstadoArreglo? _estado;
  String? _desde;
  String? _hasta;
  late String? _abierto = widget.arregloAbierto;
  MetodoPago _metodo = MetodoPago.efectivo;

  @override
  void dispose() {
    _buscarId.dispose();
    super.dispose();
  }

  /// Abre el teléfono, el correo o WhatsApp (en la web eran enlaces tel: y mailto:)
  Future<void> _abrir(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      toast(context, 'No se pudo abrir la aplicación.', error: true);
    }
  }

  Uri _whatsapp(String telefono, String mensaje) {
    var numero = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (numero.length == 10) numero = '57$numero'; // Colombia
    return Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}');
  }

  void _registrarPago(DatosApp datos, Arreglo a) {
    datos.repo.registrarPago(Pago(id: '', idArreglo: a.id, monto: a.saldo, fecha: todayKey(), metodo: _metodo));
    toast(context, 'Pago de ${cop(a.saldo)} registrado. ${a.codigo} quedó al día.');
  }

  Future<void> _entregar(DatosApp datos, Arreglo a) async {
    if (a.saldo > 0) {
      final ok = await confirmar(
        context,
        titulo: 'Arreglo con saldo pendiente',
        mensaje: '${a.codigo} de ${a.nombreCliente} aún debe ${cop(a.saldo)}. ¿Marcarlo como entregado de todas formas?',
        confirmar: 'Entregar igual',
        peligro: false,
      );
      if (!ok) return;
    }
    datos.repo.cambiarEstado(a.id, EstadoArreglo.entregado);
    if (mounted) toast(context, '${a.codigo} marcado como entregado.');
  }

  Future<void> _marcarCasa(DatosApp datos, Cliente c) async {
    final punto = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => SeleccionarUbicacionScreen(inicial: c.ubicacion, titulo: 'Casa de ${c.nombre}')),
    );
    if (punto == null) return;
    datos.repo.fijarUbicacionCliente(c.id, punto, aproximada: false);
    if (mounted) toast(context, 'Ubicación de la casa guardada.');
  }

  bool _buscando = false;

  /// Busca la casa a partir de la dirección escrita
  Future<void> _buscarPorDireccion(DatosApp datos, Cliente c) async {
    setState(() => _buscando = true);
    await ubicarPorDireccion(datos, c.id, c.direccion, c.ciudad, ScaffoldMessenger.of(context));
    if (mounted) setState(() => _buscando = false);
  }

  @override
  Widget build(BuildContext context) {
    final datos = DatosScope.of(context);
    final cliente = datos.cliente(widget.idCliente);

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.slate200)),
        iconTheme: const IconThemeData(color: AppColors.slate600),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalle del Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
            Text('Información y historial completo', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
          ],
        ),
      ),
      body: cliente == null
          ? Center(
              child: AppCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(datos.cargando ? 'Cargando cliente...' : 'No se encontró el cliente solicitado.'),
                    const SizedBox(height: 16),
                    Btn(texto: 'Volver a clientes', tipo: BtnTipo.navy, sm: true, onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
            )
          : _contenido(datos, cliente),
    );
  }

  Widget _contenido(DatosApp datos, Cliente c) {
    final todos = datos.arreglosDe(c.id)
      ..sort((a, b) => b.fechaIngreso.compareTo(a.fechaIngreso) != 0
          ? b.fechaIngreso.compareTo(a.fechaIngreso)
          : b.numero.compareTo(a.numero));
    final id = _buscarId.text.trim().toUpperCase();
    final filtrados = todos.where((a) {
      if (id.isNotEmpty && !a.codigo.contains(id) && !'${a.numero}'.contains(id)) return false;
      if (_estado != null && a.estado != _estado) return false;
      if (_desde != null && a.fechaIngreso.compareTo(_desde!) < 0) return false;
      if (_hasta != null && a.fechaIngreso.compareTo(_hasta!) > 0) return false;
      return true;
    }).toList();
    final pendiente = todos.fold<double>(0, (s, a) => s + (a.saldo > 0 ? a.saldo : 0));
    final conDeuda = todos.where((a) => a.saldo > 0).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Tarjeta del cliente ----
        AppCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(gradient: kGradienteMarca),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: Text(c.inicial, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.nombre, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                              Text('Cliente ID: ${c.numero}', style: const TextStyle(color: AppColors.blue100, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _BotonEncabezado(
                            icono: Icons.edit_outlined,
                            texto: 'Editar',
                            onTap: () => mostrarFormCliente(context, cliente: c),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BotonEncabezado(
                            icono: Icons.add,
                            texto: 'Nuevo arreglo',
                            solido: true,
                            onTap: () => mostrarFormArreglo(context, cliente: c),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'INFORMACIÓN DE CONTACTO',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 12),
                    _Contacto(icono: Icons.badge_outlined, etiqueta: 'Cédula', valor: c.cedula),
                    _Contacto(
                      icono: Icons.phone_outlined,
                      etiqueta: 'Teléfono',
                      valor: c.telefono.isEmpty ? 'Sin teléfono' : c.telefono,
                      vacio: c.telefono.isEmpty,
                      onTap: c.telefono.isEmpty ? null : () => _abrir(Uri(scheme: 'tel', path: c.telefono)),
                      accion: c.telefono.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'WhatsApp',
                              icon: const Icon(Icons.chat_outlined, color: AppColors.green600, size: 20),
                              onPressed: () => _abrir(_whatsapp(c.telefono, 'Hola ${c.nombre}, te escribimos de Interfajas.')),
                            ),
                    ),
                    _Contacto(
                      icono: Icons.mail_outline,
                      etiqueta: 'Correo electrónico',
                      valor: c.correo.isEmpty ? 'Sin correo' : c.correo,
                      vacio: c.correo.isEmpty,
                      onTap: c.correo.isEmpty ? null : () => _abrir(Uri(scheme: 'mailto', path: c.correo)),
                    ),
                    _Contacto(
                      icono: Icons.place_outlined,
                      etiqueta: 'Dirección',
                      valor: c.direccion.isEmpty ? 'Sin dirección' : '${c.direccion} · ${c.ciudad}',
                      vacio: c.direccion.isEmpty,
                    ),
                    // NUEVO en la app: casa en el mapa (para domicilios).
                    // Se ubica sola con la dirección; "Ajustar" corrige el punto a mano.
                    _Contacto(
                      icono: c.ubicacion == null ? Icons.location_off_outlined : Icons.location_on_outlined,
                      etiqueta: 'Ubicación para domicilios',
                      valor: c.ubicacion == null
                          ? 'Sin ubicar en el mapa'
                          : c.ubicacionAproximada
                              ? 'Ubicada por la dirección (aproximada)'
                              : 'Casa marcada en el mapa',
                      vacio: c.ubicacion == null,
                      accion: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.direccion.isNotEmpty && (c.ubicacion == null || c.ubicacionAproximada))
                            _buscando
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                : IconButton(
                                    tooltip: 'Buscar por la dirección',
                                    icon: const Icon(Icons.travel_explore, color: AppColors.blue, size: 20),
                                    onPressed: () => _buscarPorDireccion(datos, c),
                                  ),
                          TextButton(
                            onPressed: () => _marcarCasa(datos, c),
                            child: Text(c.ubicacion == null ? 'Marcar' : 'Ajustar'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Saldo pendiente: naranja si debe, verde si está al día
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pendiente > 0 ? AppColors.orange50 : AppColors.green50,
                        border: Border.all(color: pendiente > 0 ? AppColors.orange200 : AppColors.green200),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                pendiente > 0 ? Icons.account_balance_wallet_outlined : Icons.check_circle_outline,
                                size: 18,
                                color: pendiente > 0 ? AppColors.orange700 : AppColors.green700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Saldo pendiente',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: pendiente > 0 ? AppColors.orange700 : AppColors.green700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cop(pendiente),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: pendiente > 0 ? AppColors.orange700 : AppColors.green700,
                            ),
                          ),
                          Text(
                            pendiente > 0 ? 'En $conDeuda ${conDeuda == 1 ? 'arreglo' : 'arreglos'}' : 'El cliente está al día',
                            style: const TextStyle(fontSize: 13, color: AppColors.slate600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // ---- Historial de arreglos ----
        AppCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(AppRadius.lg)),
                          child: const Icon(Icons.history, color: AppColors.navy),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Historial de Arreglos',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate800),
                            ),
                            Text(
                              '${filtrados.length} de ${todos.length} arreglos',
                              style: const TextStyle(fontSize: 14, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(Icons.filter_alt_outlined, size: 18, color: AppColors.slate600),
                        SizedBox(width: 8),
                        Text('Filtros', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.slate600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Campo(
                      label: 'Buscar por N° Arreglo',
                      child: TextField(
                        controller: _buscarId,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(hintText: 'Ej: R001', prefixIcon: Icon(Icons.search, size: 20)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Campo(
                      label: 'Estado',
                      child: DropdownButtonFormField<int>(
                        initialValue: _estado?.index ?? -1,
                        items: [
                          const DropdownMenuItem(value: -1, child: Text('Todos')),
                          for (final e in EstadoArreglo.values) DropdownMenuItem(value: e.index, child: Text(e.etiqueta)),
                        ],
                        onChanged: (v) => setState(() => _estado = v == null || v < 0 ? null : EstadoArreglo.values[v]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _filtroFecha('Desde', _desde, (v) => _desde = v)),
                        const SizedBox(width: 12),
                        Expanded(child: _filtroFecha('Hasta', _hasta, (v) => _hasta = v)),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.slate200),
              if (filtrados.isEmpty)
                const Vacio(texto: 'No hay arreglos que coincidan con los filtros.')
              else
                for (final a in filtrados) _itemArreglo(datos, a),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filtroFecha(String etiqueta, String? valor, ValueChanged<String?> cambiar) {
    return Campo(
      label: etiqueta,
      child: InkWell(
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: valor != null ? fromDateKey(valor) : DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (d != null) setState(() => cambiar(toDateKey(d)));
        },
        child: InputDecorator(
          decoration: InputDecoration(
            suffixIcon: valor == null
                ? const Icon(Icons.calendar_today_outlined, size: 18)
                : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => cambiar(null))),
          ),
          child: Text(valor == null ? 'dd/mm/aaaa' : fechaKey(valor, 'dd/MM/y'),
              style: TextStyle(color: valor == null ? AppColors.slate400 : AppColors.slate900)),
        ),
      ),
    );
  }

  Widget _itemArreglo(DatosApp datos, Arreglo a) {
    final abierto = _abierto == a.id;
    final pagos = abierto ? datos.pagosDe(a.id) : const <Pago>[];
    Widget monto(String t, String v, Color color, {bool grande = false}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
            Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: grande ? 16 : 14)),
          ],
        );

    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate100))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _abierto = abierto ? null : a.id),
            child: Container(
              color: abierto ? AppColors.blue50.withValues(alpha: 0.5) : null,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(a.codigo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 18)),
                      const SizedBox(width: 8),
                      StatusBadge(estado: a.estado),
                      const Spacer(),
                      Icon(abierto ? Icons.expand_less : Icons.expand_more, color: AppColors.slate400),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(a.descripcion, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.slate700)),
                  const SizedBox(height: 4),
                  Text(
                    'Recibido: ${fechaKey(a.fechaIngreso)}${a.horaIngreso != null ? ', ${time12(a.horaIngreso)}' : ''}',
                    style: const TextStyle(fontSize: 13, color: AppColors.slate500),
                  ),
                  Text(
                    'Entrega: ${a.fechaEntrega == null ? 'sin fecha' : fechaKey(a.fechaEntrega)}${a.horaEntrega != null ? ', ${time12(a.horaEntrega)}' : ''}',
                    style: const TextStyle(fontSize: 13, color: AppColors.slate500),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: monto('Costo total', cop(a.valor), AppColors.slate800, grande: true)),
                      Expanded(child: monto('Pagado', cop(a.pagado), a.saldo > 0 ? AppColors.orange500 : AppColors.green600)),
                      if (a.saldo > 0) Expanded(child: monto('Saldo', cop(a.saldo), AppColors.red600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (abierto)
            Container(
              color: AppColors.slate50,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (a.saldo > 0 && !a.entregado) ...[
                    // .payment-box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        border: Border.all(color: AppColors.orange200),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.credit_card, size: 18, color: AppColors.slate800),
                                        SizedBox(width: 6),
                                        Text('Registrar Pago', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate800)),
                                      ],
                                    ),
                                    Text('Seleccione el método de pago', style: TextStyle(fontSize: 13, color: AppColors.slate500)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Saldo pendiente', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
                                  Text(
                                    cop(a.saldo),
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.orange500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SelectorMetodoPago(valor: _metodo, onChanged: (m) => setState(() => _metodo = m)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Btn(
                                  texto: 'Abono parcial',
                                  tipo: BtnTipo.outline,
                                  onPressed: () => mostrarRegistrarPago(context, a),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Btn(
                                  texto: 'Pagar todo',
                                  icono: Icons.check,
                                  tipo: BtnTipo.green,
                                  onPressed: () => _registrarPago(datos, a),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Pagos registrados',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate700),
                  ),
                  const SizedBox(height: 8),
                  if (pagos.isEmpty)
                    const Text('Aún no hay pagos para este arreglo.', style: TextStyle(fontSize: 14, color: AppColors.slate400))
                  else
                    for (final p in pagos)
                      Row(
                        children: [
                          SizedBox(width: 90, child: Text(fechaKey(p.fecha), style: const TextStyle(fontSize: 13, color: AppColors.slate500))),
                          MetodoBadge(metodo: p.metodo),
                          const Spacer(),
                          Text(cop(p.monto), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate800)),
                          IconBtn(icono: Icons.edit_outlined, onPressed: () => mostrarEditarPago(context, p, a)),
                        ],
                      ),
                  if (!a.entregado && (a.estado == EstadoArreglo.listo || a.saldo <= 0)) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (a.estado == EstadoArreglo.listo && a.telefonoCliente.isNotEmpty)
                          Btn(
                            texto: 'Avisar por WhatsApp',
                            icono: Icons.chat_outlined,
                            tipo: BtnTipo.outline,
                            onPressed: () => _abrir(_whatsapp(
                              a.telefonoCliente,
                              'Hola ${a.nombreCliente}, tu arreglo ${a.codigo} ya está listo en Interfajas.'
                              '${a.saldo > 0 ? ' Saldo pendiente: ${cop(a.saldo)}.' : ''}',
                            )),
                          ),
                        Btn(
                          texto: 'Marcar como Entregado',
                          icono: Icons.check_circle_outline,
                          tipo: BtnTipo.green,
                          onPressed: () => _entregar(datos, a),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BotonEncabezado extends StatelessWidget {
  const _BotonEncabezado({required this.icono, required this.texto, required this.onTap, this.solido = false});

  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final bool solido;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: solido ? Colors.white : Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: solido ? null : Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 18, color: solido ? AppColors.navy : Colors.white),
              const SizedBox(width: 6),
              Text(texto, style: TextStyle(fontWeight: FontWeight.w600, color: solido ? AppColors.navy : Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Contacto extends StatelessWidget {
  const _Contacto({required this.icono, required this.etiqueta, required this.valor, this.vacio = false, this.onTap, this.accion});

  final IconData icono;
  final String etiqueta;
  final String valor;
  final bool vacio;
  final VoidCallback? onTap;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Icon(icono, size: 18, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiqueta, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  Text(
                    valor,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: vacio ? AppColors.slate400 : (onTap != null ? AppColors.blue : AppColors.slate800),
                      fontStyle: vacio ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}
