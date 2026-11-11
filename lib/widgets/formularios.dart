import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/arreglo.dart';
import '../models/catalogos.dart';
import '../models/cliente.dart';
import '../models/pago.dart';
import '../services/geocodificacion_service.dart';
import '../state/datos.dart';
import '../theme/app_theme.dart';
import '../utils/formatos.dart';
import 'ui.dart';

// =====================================================================
//  Modales de la web: client-form-modal, nuevo/editar arreglo,
//  registrar pago y payment-edit-modal.
// =====================================================================

/// Formatea el dinero mientras se escribe: 45000 -> 45.000 (appMoneyInput)
class FormatoPesos extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitos = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.isEmpty) return const TextEditingValue();
    final texto = cop(int.parse(digitos)).substring(1);
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}

String? _requerido(String? v) => (v ?? '').trim().isEmpty ? 'Este campo es obligatorio.' : null;

// ---------------------------------------------------------------------
//  Nuevo / Editar Cliente. Devuelve el id del cliente guardado.
// ---------------------------------------------------------------------
Future<String?> mostrarFormCliente(BuildContext context, {Cliente? cliente}) {
  final datos = DatosScope.read(context);
  return mostrarModal<String>(
    context,
    titulo: cliente == null ? 'Nuevo Cliente' : 'Editar Cliente',
    icono: cliente == null ? Icons.person_add_alt : Icons.edit_outlined,
    cuerpo: (ctx) => _FormCliente(datos: datos, cliente: cliente),
  );
}

class _FormCliente extends StatefulWidget {
  const _FormCliente({required this.datos, this.cliente});

  final DatosApp datos;
  final Cliente? cliente;

  @override
  State<_FormCliente> createState() => _FormClienteState();
}

class _FormClienteState extends State<_FormCliente> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.cliente?.nombre);
  late final _cedula = TextEditingController(text: widget.cliente?.cedula);
  late final _correo = TextEditingController(text: widget.cliente?.correo);
  late final _telefono = TextEditingController(text: widget.cliente?.telefono);
  late final _direccion = TextEditingController(text: widget.cliente?.direccion);
  late final _ciudad = TextEditingController(text: widget.cliente?.ciudad ?? 'Neiva');

  @override
  void dispose() {
    for (final c in [_nombre, _cedula, _correo, _telefono, _direccion, _ciudad]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    final cedula = _cedula.text.trim();
    final repetida = widget.datos.clientes.any((c) => c.cedula == cedula && c.id != widget.cliente?.id);
    if (repetida) {
      toast(context, 'Ya existe un cliente con la cédula $cedula.', error: true);
      return;
    }
    final anterior = widget.cliente;
    final direccion = _direccion.text.trim();
    final ciudad = _ciudad.text.trim().isEmpty ? 'Neiva' : _ciudad.text.trim();
    final cambioDireccion = anterior == null || anterior.direccion != direccion || anterior.ciudad != ciudad;
    final c = Cliente(
      id: anterior?.id ?? '',
      numero: anterior?.numero ?? widget.datos.siguienteNumeroCliente,
      nombre: _nombre.text.trim(),
      cedula: cedula,
      telefono: _telefono.text.trim(),
      correo: _correo.text.trim(),
      direccion: direccion,
      ciudad: ciudad,
      ubicacion: anterior?.ubicacion,
      ubicacionAproximada: anterior?.ubicacionAproximada ?? false,
    );
    final repo = widget.datos.repo;
    String id;
    if (anterior == null) {
      id = repo.crearCliente(c);
    } else {
      repo.actualizarCliente(c, widget.datos.arreglosDe(c.id));
      id = c.id;
    }
    final mensajero = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(id);
    toast(context, anterior == null ? 'Cliente creado.' : 'Cliente actualizado.');
    // Ubica la casa en el mapa a partir de la dirección (sin marcar el punto a mano)
    if (direccion.isNotEmpty && (cambioDireccion || c.ubicacion == null)) {
      ubicarPorDireccion(widget.datos, id, direccion, ciudad, mensajero);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Campo(
            label: 'Nombre Completo *',
            child: TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Ej: María Rodríguez'),
              validator: _requerido,
            ),
          ),
          const SizedBox(height: 16),
          Campo(
            label: 'Cédula *',
            child: TextFormField(
              controller: _cedula,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '123456789'),
              validator: _requerido,
            ),
          ),
          const SizedBox(height: 16),
          Campo(
            label: 'Correo Electrónico',
            opcional: true,
            child: TextFormField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'ejemplo@correo.com'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                return t.contains('@') && t.contains('.') ? null : 'Ingresa un correo válido.';
              },
            ),
          ),
          const SizedBox(height: 16),
          Campo(
            label: 'Teléfono *',
            child: TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: '3001234567'),
              validator: _requerido,
            ),
          ),
          const SizedBox(height: 16),
          Campo(
            label: 'Dirección',
            opcional: true,
            hint: 'Con la dirección la app ubica la casa en el mapa de Domicilios.',
            child: TextFormField(
              controller: _direccion,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Cra 5 # 12-34, barrio Centro'),
            ),
          ),
          const SizedBox(height: 16),
          Campo(
            label: 'Ciudad / municipio',
            child: TextFormField(
              controller: _ciudad,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Neiva'),
            ),
          ),
          const SizedBox(height: 8),
          PieModal(
            textoAccion: widget.cliente == null ? 'Crear Cliente' : 'Guardar Cambios',
            tipo: BtnTipo.cyan,
            onAccion: _guardar,
          ),
        ],
      ),
    );
  }
}

/// Busca la dirección en OpenStreetMap y guarda el punto del cliente.
/// Corre en segundo plano: el formulario ya se cerró.
Future<bool> ubicarPorDireccion(
  DatosApp datos,
  String idCliente,
  String direccion,
  String ciudad,
  ScaffoldMessengerState mensajero,
) async {
  final punto = await GeocodificacionService().buscar(direccion, ciudad);
  void aviso(String t, Color color) => mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t), backgroundColor: color, duration: const Duration(seconds: 6)));
  if (punto == null) {
    aviso(
      'No se encontró "$direccion" en el mapa. Márcala a mano desde el detalle del cliente.',
      AppColors.orange700,
    );
    return false;
  }
  datos.repo.fijarUbicacionCliente(idCliente, punto, aproximada: true);
  aviso('Casa ubicada en el mapa a partir de la dirección. Revisa que el punto esté bien.', AppColors.green600);
  return true;
}

// ---------------------------------------------------------------------
//  Nuevo / Editar Arreglo
// ---------------------------------------------------------------------
Future<void> mostrarFormArreglo(BuildContext context, {Arreglo? editar, Cliente? cliente}) {
  final datos = DatosScope.read(context);
  return mostrarModal<void>(
    context,
    titulo: editar == null ? 'Nuevo Arreglo' : 'Editar Arreglo ${editar.codigo}',
    cuerpo: (ctx) => _FormArreglo(datos: datos, editar: editar, clienteFijo: cliente),
  );
}

class _FormArreglo extends StatefulWidget {
  const _FormArreglo({required this.datos, this.editar, this.clienteFijo});

  final DatosApp datos;
  final Arreglo? editar;
  final Cliente? clienteFijo;

  @override
  State<_FormArreglo> createState() => _FormArregloState();
}

class _FormArregloState extends State<_FormArreglo> {
  final _form = GlobalKey<FormState>();
  final _busqueda = TextEditingController();
  late final _descripcion = TextEditingController(text: widget.editar?.descripcion);
  late final _costo = TextEditingController(
    text: widget.editar == null ? '' : cop(widget.editar!.valor).substring(1),
  );
  final _abono = TextEditingController();

  Cliente? _cliente;
  late EstadoArreglo _estado = widget.editar?.estado ?? EstadoArreglo.pendiente;
  late String _fechaRecibido = widget.editar?.fechaIngreso ?? todayKey();
  late String _horaRecibido = widget.editar?.horaIngreso ?? toTimeKey(DateTime.now());
  late String? _fechaEntrega = widget.editar?.fechaEntrega;
  late String? _horaEntrega = widget.editar?.horaEntrega;
  late bool _domicilio = widget.editar?.domicilio ?? false;
  MetodoPago _metodo = MetodoPago.efectivo;

  @override
  void initState() {
    super.initState();
    _cliente = widget.clienteFijo ??
        (widget.editar == null ? null : widget.datos.cliente(widget.editar!.idCliente));
  }

  @override
  void dispose() {
    for (final c in [_busqueda, _descripcion, _costo, _abono]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Cliente> get _sugerencias {
    final t = normalizar(_busqueda.text);
    if (t.length < 2) return [];
    return widget.datos.clientes
        .where((c) => normalizar(c.nombre).contains(t) || c.cedula.contains(t) || c.telefono.contains(t))
        .take(6)
        .toList();
  }

  Future<void> _nuevoCliente() async {
    final id = await mostrarFormCliente(context);
    if (id == null || !mounted) return;
    // El cliente ya está en la caché local aunque no haya internet.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _cliente = widget.datos.cliente(id);
      _busqueda.clear();
    });
  }

  Future<void> _elegirFecha(String? actual, ValueChanged<String> listo, {String? minimo}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: actual != null ? fromDateKey(actual) : DateTime.now(),
      firstDate: minimo != null ? fromDateKey(minimo) : DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => listo(toDateKey(d)));
  }

  Future<void> _elegirHora(String? actual, ValueChanged<String> listo) async {
    final p = (actual ?? '08:00').split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
    );
    if (t != null) {
      setState(() => listo('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'));
    }
  }

  void _guardar() {
    if (_cliente == null) {
      toast(context, 'Busca y selecciona un cliente.', error: true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    final costo = leerPesos(_costo.text) ?? 0;
    final abono = leerPesos(_abono.text) ?? 0;
    if (widget.editar == null && abono > costo) {
      toast(context, 'El abono no puede ser mayor que el costo.', error: true);
      return;
    }
    final c = _cliente!;
    final anterior = widget.editar;
    final arreglo = Arreglo(
      id: anterior?.id ?? '',
      numero: anterior?.numero ?? widget.datos.siguienteNumeroArreglo,
      idCliente: c.id,
      nombreCliente: c.nombre,
      cedulaCliente: c.cedula,
      telefonoCliente: c.telefono,
      descripcion: _descripcion.text.trim(),
      estado: _estado,
      fechaIngreso: _fechaRecibido,
      horaIngreso: _horaRecibido,
      fechaEntrega: _fechaEntrega,
      horaEntrega: _fechaEntrega == null ? null : _horaEntrega,
      valor: costo,
      domicilio: _domicilio,
    );
    final repo = widget.datos.repo;
    if (anterior == null) {
      repo.crearArreglo(arreglo, abono: abono, metodo: _metodo);
      toast(context, 'Arreglo ${arreglo.codigo} registrado.');
    } else {
      repo.actualizarArreglo(arreglo);
      toast(context, 'Arreglo ${arreglo.codigo} actualizado.');
    }
    Navigator.of(context).pop();
  }

  Widget _selectorFechaHora(String etiqueta, String? valor, IconData icono, VoidCallback onTap, {bool habilitado = true}) {
    return Campo(
      label: etiqueta,
      child: InkWell(
        onTap: habilitado ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InputDecorator(
          decoration: InputDecoration(
            enabled: habilitado,
            suffixIcon: Icon(icono, size: 18),
            fillColor: habilitado ? AppColors.white : AppColors.slate50,
          ),
          child: Text(
            valor ?? 'Sin definir',
            style: TextStyle(color: valor == null ? AppColors.slate400 : AppColors.slate900),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.editar;
    final sugerencias = _sugerencias;
    final c = _cliente;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Búsqueda de cliente ----
          if (widget.clienteFijo == null) ...[
            Campo(
              label: 'Buscar Cliente',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _busqueda,
                      onChanged: (_) => setState(() => _cliente = null),
                      decoration: const InputDecoration(
                        hintText: 'Cédula, teléfono o nombre',
                        prefixIcon: Icon(Icons.search, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Btn(texto: 'Nuevo', icono: Icons.person_add_alt, tipo: BtnTipo.cyan, onPressed: _nuevoCliente),
                ],
              ),
            ),
            if (c == null && _busqueda.text.trim().length >= 2)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: AppColors.slate200),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: AppColors.slate50,
                      child: Text(
                        sugerencias.length == 1 ? '1 coincidencia encontrada' : '${sugerencias.length} coincidencias encontradas',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                      ),
                    ),
                    for (final s in sugerencias)
                      InkWell(
                        onTap: () => setState(() {
                          _cliente = s;
                          _busqueda.text = s.nombre;
                          FocusScope.of(context).unfocus();
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate800)),
                              Text(
                                'CC ${s.cedula}  ·  ${s.telefono}',
                                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
          if (c != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.green50,
                border: Border.all(color: AppColors.green200),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: AppColors.green100, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 18, color: AppColors.green600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate800)),
                        Text(
                          'Cédula: ${c.cedula} • Tel: ${c.telefono}',
                          style: const TextStyle(fontSize: 13, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ---- Estado (solo al editar) ----
          if (editando != null) ...[
            Campo(
              label: 'Estado',
              child: DropdownButtonFormField<EstadoArreglo>(
                initialValue: _estado,
                items: [
                  for (final e in EstadoArreglo.values) DropdownMenuItem(value: e, child: Text(e.etiqueta)),
                ],
                onChanged: (e) => setState(() => _estado = e ?? _estado),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: _selectorFechaHora(
                  'Fecha de Recepción',
                  fechaKey(_fechaRecibido, 'd MMM y'),
                  Icons.calendar_today_outlined,
                  () => _elegirFecha(_fechaRecibido, (v) => _fechaRecibido = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _selectorFechaHora(
                  'Hora de Recepción',
                  time12(_horaRecibido),
                  Icons.schedule,
                  () => _elegirHora(_horaRecibido, (v) => _horaRecibido = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Campo(
            label: 'Descripción del Arreglo',
            child: TextFormField(
              controller: _descripcion,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Describe el arreglo a realizar.' : null,
            ),
          ),
          const SizedBox(height: 16),
          Campo(
            label: 'Costo Total (\$)',
            child: TextFormField(
              controller: _costo,
              keyboardType: TextInputType.number,
              inputFormatters: [FormatoPesos()],
              decoration: const InputDecoration(hintText: '0', prefixText: '\$ '),
              validator: (v) => (leerPesos(v ?? '') ?? 0) <= 0 ? 'Ingresa el costo total.' : null,
            ),
          ),
          const SizedBox(height: 16),
          if (editando != null)
            Campo(
              label: 'Pagado',
              hint: 'Los pagos se registran desde el detalle del arreglo o del cliente.',
              child: Text.rich(
                TextSpan(
                  text: cop(editando.pagado),
                  children: [
                    TextSpan(
                      text: ' · saldo ${cop(editando.saldo)}',
                      style: const TextStyle(color: AppColors.slate400, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate800),
              ),
            )
          else ...[
            Campo(
              label: 'Abono inicial (\$)',
              child: TextFormField(
                controller: _abono,
                keyboardType: TextInputType.number,
                inputFormatters: [FormatoPesos()],
                decoration: const InputDecoration(hintText: '0', prefixText: '\$ '),
              ),
            ),
            const SizedBox(height: 16),
            Campo(
              label: 'Método de Pago',
              hint: 'Requerido solo si se registra un abono',
              child: SelectorMetodoPago(valor: _metodo, onChanged: (m) => setState(() => _metodo = m)),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _selectorFechaHora(
                  'Fecha de Entrega',
                  _fechaEntrega == null ? null : fechaKey(_fechaEntrega, 'd MMM y'),
                  Icons.event,
                  () => _elegirFecha(_fechaEntrega, (v) => _fechaEntrega = v, minimo: _fechaRecibido),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _selectorFechaHora(
                  'Hora de Entrega',
                  _horaEntrega == null ? null : time12(_horaEntrega),
                  Icons.schedule,
                  () => _elegirHora(_horaEntrega, (v) => _horaEntrega = v),
                  habilitado: _fechaEntrega != null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // NUEVO en la app móvil: entrega a domicilio (aparece en el mapa)
          Container(
            decoration: BoxDecoration(
              color: _domicilio ? AppColors.blue50 : AppColors.slate50,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: _domicilio ? AppColors.blue200 : AppColors.slate200),
            ),
            child: SwitchListTile(
              value: _domicilio,
              onChanged: (v) => setState(() => _domicilio = v),
              activeThumbColor: AppColors.blue,
              secondary: const Icon(Icons.delivery_dining_outlined, color: AppColors.navy),
              title: const Text('Entregar a domicilio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(
                c != null && _domicilio && c.ubicacion == null
                    ? 'Marca la casa del cliente en el mapa desde su detalle'
                    : 'Aparecerá en el mapa de Domicilios',
                style: TextStyle(
                  fontSize: 12,
                  color: c != null && _domicilio && c.ubicacion == null ? AppColors.orange700 : AppColors.slate500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          PieModal(
            textoAccion: editando != null ? 'Guardar Cambios' : 'Registrar Arreglo',
            tipo: BtnTipo.navy,
            onAccion: _guardar,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
//  Registrar Pago
// ---------------------------------------------------------------------
Future<void> mostrarRegistrarPago(BuildContext context, Arreglo a) {
  final datos = DatosScope.read(context);
  return mostrarModal<void>(
    context,
    titulo: 'Registrar Pago',
    subtitulo: '${a.codigo} · ${a.nombreCliente}',
    cuerpo: (ctx) => _FormPago(datos: datos, arreglo: a),
  );
}

/// .payment-summary: Costo total / Pagado / Saldo
class ResumenPago extends StatelessWidget {
  const ResumenPago({super.key, required this.arreglo});

  final Arreglo arreglo;

  @override
  Widget build(BuildContext context) {
    final a = arreglo;
    Widget celda(String t, String v, {Color? color, Color? fondo}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(color: fondo ?? AppColors.slate50, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Column(
              children: [
                Text(t, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                const SizedBox(height: 2),
                FittedBox(
                  child: Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppColors.slate800)),
                ),
              ],
            ),
          ),
        );
    return Row(
      children: [
        celda('Costo total', cop(a.valor)),
        const SizedBox(width: 8),
        celda('Pagado', cop(a.pagado)),
        const SizedBox(width: 8),
        a.saldo > 0
            ? celda(a.conDeuda ? 'Debe' : 'Saldo', cop(a.saldo), color: AppColors.orange700, fondo: AppColors.orange50)
            : celda('Estado', 'Pagado', color: AppColors.green700, fondo: AppColors.green50),
      ],
    );
  }
}

class _FormPago extends StatefulWidget {
  const _FormPago({required this.datos, required this.arreglo});

  final DatosApp datos;
  final Arreglo arreglo;

  @override
  State<_FormPago> createState() => _FormPagoState();
}

class _FormPagoState extends State<_FormPago> {
  final _monto = TextEditingController();
  MetodoPago _metodo = MetodoPago.efectivo;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  void _guardar() {
    final a = widget.arreglo;
    final monto = leerPesos(_monto.text) ?? 0;
    if (monto <= 0) {
      toast(context, 'Ingresa el monto a pagar.', error: true);
      return;
    }
    if (monto > a.saldo) {
      toast(context, 'El monto supera el saldo pendiente (${cop(a.saldo)}).', error: true);
      return;
    }
    widget.datos.repo.registrarPago(Pago(id: '', idArreglo: a.id, monto: monto, fecha: todayKey(), metodo: _metodo));
    Navigator.of(context).pop();
    toast(context, 'Pago de ${cop(monto)} registrado para ${a.codigo}.');
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.arreglo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (a.conDeuda) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.red50,
              border: Border.all(color: AppColors.red200),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Text(
              'Este arreglo ya fue entregado y aún tiene saldo pendiente.',
              style: TextStyle(color: AppColors.red700, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ResumenPago(arreglo: a),
        const SizedBox(height: 16),
        Campo(
          label: 'Monto a pagar',
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _monto,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FormatoPesos()],
                  decoration: const InputDecoration(hintText: '0', prefixText: '\$ '),
                ),
              ),
              const SizedBox(width: 8),
              Btn(
                texto: 'Pagar todo',
                tipo: BtnTipo.outline,
                onPressed: () => _monto.text = cop(a.saldo).substring(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Campo(
          label: 'Método de pago',
          child: SelectorMetodoPago(valor: _metodo, onChanged: (m) => setState(() => _metodo = m)),
        ),
        const SizedBox(height: 8),
        PieModal(textoAccion: 'Registrar Pago', onAccion: _guardar),
      ],
    );
  }
}

// ---------------------------------------------------------------------
//  Editar / eliminar pago (payment-edit-modal)
// ---------------------------------------------------------------------
Future<void> mostrarEditarPago(BuildContext context, Pago p, Arreglo a) {
  final datos = DatosScope.read(context);
  return mostrarModal<void>(
    context,
    titulo: 'Editar pago',
    subtitulo: '${a.codigo} · ${a.nombreCliente}',
    cuerpo: (ctx) => _EditarPago(datos: datos, pago: p, arreglo: a),
  );
}

class _EditarPago extends StatefulWidget {
  const _EditarPago({required this.datos, required this.pago, required this.arreglo});

  final DatosApp datos;
  final Pago pago;
  final Arreglo arreglo;

  @override
  State<_EditarPago> createState() => _EditarPagoState();
}

class _EditarPagoState extends State<_EditarPago> {
  late final _monto = TextEditingController(text: cop(widget.pago.monto).substring(1));
  late MetodoPago _metodo = MetodoPago.seleccionables.contains(widget.pago.metodo) ? widget.pago.metodo : MetodoPago.efectivo;
  late String _fecha = widget.pago.fecha;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  void _guardar() {
    final monto = leerPesos(_monto.text) ?? 0;
    final maximo = widget.arreglo.saldo + widget.pago.monto;
    if (monto <= 0 || monto > maximo) {
      toast(context, 'El monto debe estar entre \$1 y ${cop(maximo)}.', error: true);
      return;
    }
    widget.datos.repo.actualizarPago(
      Pago(id: widget.pago.id, idArreglo: widget.pago.idArreglo, monto: monto, fecha: _fecha, metodo: _metodo),
    );
    Navigator.of(context).pop();
    toast(context, 'Pago actualizado.');
  }

  Future<void> _eliminar() async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar pago',
      mensaje: '¿Eliminar el pago de ${cop(widget.pago.monto)}? El saldo del arreglo volverá a subir.',
    );
    if (!ok || !mounted) return;
    widget.datos.repo.eliminarPago(widget.pago.id);
    Navigator.of(context).pop();
    toast(context, 'Pago eliminado.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Campo(
          label: 'Monto',
          child: TextField(
            controller: _monto,
            keyboardType: TextInputType.number,
            inputFormatters: [FormatoPesos()],
            decoration: const InputDecoration(prefixText: '\$ '),
          ),
        ),
        const SizedBox(height: 16),
        Campo(
          label: 'Fecha del pago',
          child: InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: fromDateKey(_fecha),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _fecha = toDateKey(d));
            },
            child: InputDecorator(
              decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(fechaKey(_fecha)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Campo(
          label: 'Método de pago',
          child: SelectorMetodoPago(valor: _metodo, onChanged: (m) => setState(() => _metodo = m)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            TextButton.icon(
              onPressed: _eliminar,
              icon: const Icon(Icons.delete_outline, color: AppColors.red600, size: 18),
              label: const Text('Eliminar', style: TextStyle(color: AppColors.red600)),
            ),
            const Spacer(),
            Btn(texto: 'Guardar', onPressed: _guardar),
          ],
        ),
      ],
    );
  }
}
