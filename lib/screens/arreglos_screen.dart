import 'package:flutter/material.dart';

import '../models/arreglo.dart';
import '../models/catalogos.dart';
import '../state/datos.dart';
import '../theme/app_theme.dart';
import '../utils/formatos.dart';
import '../widgets/formularios.dart';
import '../widgets/ui.dart';
import 'cliente_detalle_screen.dart';

/// "Gestión de Arreglos" de la web, en su versión celular: buscador,
/// desplegable de estado y una tarjeta por arreglo.
class ArreglosScreen extends StatefulWidget {
  const ArreglosScreen({super.key});

  @override
  State<ArreglosScreen> createState() => _ArreglosScreenState();
}

class _ArreglosScreenState extends State<ArreglosScreen> {
  final _buscar = TextEditingController();
  EstadoArreglo? _filtro; // null = Todos

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  /// Claves de búsqueda de una fecha: 30/09, 30/09/2026, 30 sept, 30 de septiembre
  static List<String> _clavesFecha(String? key) {
    if (key == null) return [];
    final d = fromDateKey(key);
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final mes = fecha(d, 'MMMM');
    return ['$dd/$mm', '${d.day}/${d.month}', '$dd/$mm/${d.year}', '${d.day} ${mes.substring(0, 3)}', '${d.day} de $mes', key];
  }

  List<Arreglo> _filtrados(DatosApp datos) {
    final t = normalizar(_buscar.text);
    final lista = datos.arreglos.where((a) {
      final coincide = t.isEmpty ||
          [a.codigo, '${a.numero}', a.nombreCliente, a.cedulaCliente, ..._clavesFecha(a.fechaEntrega), ..._clavesFecha(a.fechaIngreso)]
              .any((v) => normalizar(v).contains(t));
      return coincide && (_filtro == null || a.estado == _filtro);
    }).toList();
    // Más reciente primero; en "Pendientes", primero los más antiguos
    final dir = _filtro == EstadoArreglo.pendiente ? 1 : -1;
    lista.sort((a, b) {
      final f = (a.fechaEntrega ?? a.fechaIngreso).compareTo(b.fechaEntrega ?? b.fechaIngreso);
      if (f != 0) return dir * f;
      final h = (a.horaEntrega ?? '').compareTo(b.horaEntrega ?? '');
      return dir * (h != 0 ? h : a.numero.compareTo(b.numero));
    });
    return lista;
  }

  Future<void> _elegirFecha() async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => _buscar.text = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}');
  }

  @override
  Widget build(BuildContext context) {
    final datos = DatosScope.of(context);
    final lista = _filtrados(datos);
    int cuenta(EstadoArreglo? f) => f == null ? datos.arreglos.length : datos.arreglos.where((a) => a.estado == f).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          titulo: 'Gestión de Arreglos',
          subtitulo: 'Control y seguimiento de órdenes de trabajo',
          accion: Btn(texto: 'Nuevo Arreglo', icono: Icons.add, full: true, onPressed: () => mostrarFormArreglo(context)),
        ),
        const SizedBox(height: 24),
        // Filtros
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _buscar,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente, ID, cédula o fecha',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_buscar.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.slate400),
                          onPressed: () => setState(_buscar.clear),
                        ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.slate400),
                        onPressed: _elegirFecha,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Celular: los filtros en un desplegable (app-select-dropdown)
              DropdownButtonFormField<int>(
                initialValue: _filtro == null ? -1 : _filtro!.index,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_list, size: 20)),
                items: [
                  DropdownMenuItem(value: -1, child: Text('Todos (${cuenta(null)})')),
                  for (final e in EstadoArreglo.values)
                    DropdownMenuItem(
                      value: e.index,
                      child: Row(
                        children: [
                          StatusDot(color: e.punto),
                          const SizedBox(width: 8),
                          Text('${_plural(e)} (${cuenta(e)})'),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _filtro = v == null || v < 0 ? null : EstadoArreglo.values[v]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (lista.isEmpty)
          AppCard(
            child: Vacio(
              texto: datos.cargando ? 'Cargando arreglos...' : 'No se encontraron arreglos con los filtros actuales.',
            ),
          )
        else
          for (final a in lista) ...[
            TarjetaArreglo(arreglo: a),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  static String _plural(EstadoArreglo e) => switch (e) {
        EstadoArreglo.pendiente => 'Pendientes',
        EstadoArreglo.enProceso => 'En Taller',
        EstadoArreglo.listo => 'Listos',
        EstadoArreglo.entregado => 'Entregados',
      };
}

/// Alerta de entrega: atrasado (rojo) o "Entrega hoy" (naranja)
(bool atrasado, String texto)? alertaEntrega(Arreglo a) {
  if (a.entregado || a.fechaEntrega == null) return null;
  final hoy = todayKey();
  if (a.fechaEntrega == hoy) return (false, 'Entrega hoy');
  if (a.fechaEntrega!.compareTo(hoy) < 0 &&
      (a.estado == EstadoArreglo.pendiente || a.estado == EstadoArreglo.enProceso)) {
    final dias = fromDateKey(hoy).difference(fromDateKey(a.fechaEntrega!)).inDays;
    return (true, dias == 1 ? 'Atrasado 1 día' : 'Atrasado $dias días');
  }
  return null;
}

class _ChipAlerta extends StatelessWidget {
  const _ChipAlerta({required this.atrasado, required this.texto});

  final bool atrasado;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: atrasado ? AppColors.red100 : AppColors.orange100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(atrasado ? Icons.warning_amber_rounded : Icons.schedule, size: 12, color: atrasado ? AppColors.red700 : AppColors.orange700),
            const SizedBox(width: 4),
            Text(
              texto,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: atrasado ? AppColors.red700 : AppColors.orange700),
            ),
          ],
        ),
      );
}

/// Fila de la tabla de arreglos convertida en tarjeta (diseño celular de la web):
///   código ........ estado
///   cliente
///   descripción
///   fecha entrega .. pago
///   ───────────── acciones
class TarjetaArreglo extends StatelessWidget {
  const TarjetaArreglo({super.key, required this.arreglo});

  final Arreglo arreglo;

  Future<void> _cambiarEstado(BuildContext context, EstadoArreglo e) async {
    final a = arreglo;
    if (e == a.estado) return;
    // "Entregar" lleva al detalle del cliente con el arreglo abierto (para cobrar y entregar)
    if (e == EstadoArreglo.entregado) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ClienteDetalleScreen(idCliente: a.idCliente, arregloAbierto: a.id)),
      );
      return;
    }
    DatosScope.read(context).repo.cambiarEstado(a.id, e);
    toast(context, '${a.codigo} ahora está en "${e.etiqueta}".');
  }

  Future<void> _eliminar(BuildContext context) async {
    final datos = DatosScope.read(context);
    final ok = await confirmar(
      context,
      titulo: 'Eliminar arreglo',
      mensaje: '¿Eliminar ${arreglo.codigo} de ${arreglo.nombreCliente}? También se borrarán sus pagos.',
    );
    if (!ok || !context.mounted) return;
    datos.repo.eliminarArreglo(arreglo.id, datos.pagosDe(arreglo.id));
    toast(context, '${arreglo.codigo} eliminado.');
  }

  @override
  Widget build(BuildContext context) {
    final a = arreglo;
    final datos = DatosScope.of(context);
    final alerta = alertaEntrega(a);
    final metodo = datos.ultimoMetodo(a.id);
    final atrasado = alerta?.$1 == true;

    return Container(
      decoration: BoxDecoration(
        color: atrasado ? AppColors.red50 : AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: atrasado
              ? AppColors.red200
              : alerta != null
                  ? AppColors.orange300
                  : a.conDeuda
                      ? AppColors.red200
                      : AppColors.slate200,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: () => mostrarDetalleArreglo(context, a.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(a.codigo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                    if (a.domicilio) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.delivery_dining, size: 16, color: AppColors.cyan),
                    ],
                    const Spacer(),
                    // Cambio rápido de estado
                    PopupMenuButton<EstadoArreglo>(
                      tooltip: 'Cambiar estado',
                      color: AppColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      onSelected: (e) => _cambiarEstado(context, e),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          enabled: false,
                          height: 32,
                          child: Text(
                            'Cambiar estado de ${a.codigo}',
                            style: const TextStyle(fontSize: 12, color: AppColors.slate400, fontWeight: FontWeight.w600),
                          ),
                        ),
                        for (final e in EstadoArreglo.values)
                          PopupMenuItem(
                            value: e,
                            child: Row(
                              children: [
                                StatusDot(color: e.punto),
                                const SizedBox(width: 8),
                                Text(
                                  e == EstadoArreglo.entregado && e != a.estado ? 'Entregar' : e.etiqueta,
                                  style: TextStyle(fontWeight: e == a.estado ? FontWeight.bold : FontWeight.w500),
                                ),
                                const Spacer(),
                                if (e == a.estado)
                                  const Icon(Icons.check, size: 16, color: AppColors.blue)
                                else if (e == EstadoArreglo.entregado)
                                  const Text('ir al cliente', style: TextStyle(fontSize: 11, color: AppColors.slate400)),
                              ],
                            ),
                          ),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusBadge(estado: a.estado),
                          const Icon(Icons.expand_more, size: 16, color: AppColors.slate400),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(a.nombreCliente, style: const TextStyle(color: AppColors.slate700, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(
                  a.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.slate600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fecha de entrega
                    Expanded(
                      child: a.fechaEntrega == null
                          ? const Text('Sin fecha', style: TextStyle(fontSize: 12, color: AppColors.slate400))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.slate400),
                                    const SizedBox(width: 8),
                                    Text(fechaKey(a.fechaEntrega, 'd MMM, y'), style: const TextStyle(color: AppColors.slate700, fontSize: 14)),
                                  ],
                                ),
                                if (a.horaEntrega != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 24, top: 2),
                                    child: Text(time12(a.horaEntrega), style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
                                  ),
                                if (alerta != null) ...[
                                  const SizedBox(height: 6),
                                  _ChipAlerta(atrasado: alerta.$1, texto: alerta.$2),
                                ],
                              ],
                            ),
                    ),
                    // Pago
                    SizedBox(
                      width: 144,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text(cop(a.pagado), style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.slate700)),
                              if (metodo != null) MetodoBadge(metodo: metodo, sm: true),
                            ],
                          ),
                          Text('de ${cop(a.valor)}', style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
                          const SizedBox(height: 4),
                          BarraPago(porcentaje: a.porcentajePagado, deuda: a.conDeuda),
                          if (a.conDeuda)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.red100, borderRadius: BorderRadius.circular(999)),
                              child: Text(
                                'Debe ${cop(a.saldo)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.red700),
                              ),
                            )
                          else if (a.saldo > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Saldo ${cop(a.saldo)}', style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.slate100),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (a.saldo > 0)
                      IconBtn(
                        icono: Icons.attach_money,
                        tooltip: 'Registrar pago',
                        color: a.conDeuda ? AppColors.red600 : AppColors.green600,
                        onPressed: () => mostrarRegistrarPago(context, a),
                      ),
                    IconBtn(icono: Icons.edit_outlined, tooltip: 'Editar', onPressed: () => mostrarFormArreglo(context, editar: a)),
                    IconBtn(
                      icono: Icons.delete_outline,
                      tooltip: 'Eliminar',
                      color: AppColors.red500,
                      onPressed: () => _eliminar(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
//  Panel lateral de detalle (.drawer) → hoja inferior en el celular
// ---------------------------------------------------------------------
Future<void> mostrarDetalleArreglo(BuildContext context, String idArreglo) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
    clipBehavior: Clip.antiAlias,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => _DetalleArreglo(idArreglo: idArreglo, scroll: scroll),
    ),
  );
}

class _DetalleArreglo extends StatelessWidget {
  const _DetalleArreglo({required this.idArreglo, required this.scroll});

  final String idArreglo;
  final ScrollController scroll;

  Widget _seccion(String titulo, Widget hijo) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo.toUpperCase(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: AppColors.slate500),
            ),
            const SizedBox(height: 8),
            hijo,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final datos = DatosScope.of(context);
    final a = datos.arreglo(idArreglo);
    if (a == null) return const Vacio(texto: 'Este arreglo ya no existe.');
    final cliente = datos.cliente(a.idCliente);
    final pagos = datos.pagosDe(a.id);
    final alerta = alertaEntrega(a);

    Widget fechaBox(String t, String? f, String? h) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                Text(
                  f == null ? 'Sin fecha' : fechaKey(f, 'EEE d MMM, y'),
                  style: TextStyle(fontWeight: FontWeight.w600, color: f == null ? AppColors.slate400 : AppColors.slate800),
                ),
                if (h != null) Text(time12(h), style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
              ],
            ),
          ),
        );

    return Column(
      children: [
        // Encabezado
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate100))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.codigo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        StatusBadge(estado: a.estado),
                        if (alerta != null) _ChipAlerta(atrasado: alerta.$1, texto: alerta.$2),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppColors.slate400)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(20),
            children: [
              _seccion(
                'Cliente',
                Material(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(
                        MaterialPageRoute(builder: (_) => ClienteDetalleScreen(idCliente: a.idCliente, arregloAbierto: a.id)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.navy,
                            child: Text(
                              a.nombreCliente.isEmpty ? '?' : a.nombreCliente[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.nombreCliente, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate800)),
                                Text(
                                  [
                                    if (a.cedulaCliente.isNotEmpty) 'C.C. ${a.cedulaCliente}',
                                    if (a.telefonoCliente.isNotEmpty) a.telefonoCliente,
                                  ].join(' · '),
                                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                                ),
                                if (cliente != null && cliente.correo.isNotEmpty)
                                  Text(cliente.correo, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.slate400),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _seccion(
                'Descripción',
                Text(
                  a.descripcion.isEmpty ? 'Sin descripción.' : a.descripcion,
                  style: const TextStyle(color: AppColors.slate700, height: 1.5),
                ),
              ),
              _seccion(
                'Fechas',
                Row(
                  children: [
                    fechaBox('Recibido', a.fechaIngreso, a.horaIngreso),
                    const SizedBox(width: 12),
                    fechaBox('Entrega', a.fechaEntrega, a.horaEntrega),
                  ],
                ),
              ),
              _seccion(
                'Pagos',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ResumenPago(arreglo: a),
                    const SizedBox(height: 12),
                    BarraPago(porcentaje: a.porcentajePagado, deuda: a.conDeuda),
                    const SizedBox(height: 8),
                    if (pagos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Aún no hay pagos registrados.', style: TextStyle(color: AppColors.slate400, fontSize: 14)),
                      ),
                    for (final p in pagos)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate100))),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(fechaKey(p.fecha), style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
                            ),
                            MetodoBadge(metodo: p.metodo, sm: true),
                            const Spacer(),
                            Text(cop(p.monto), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800)),
                            IconBtn(
                              icono: Icons.edit_outlined,
                              tooltip: 'Editar o eliminar pago',
                              onPressed: () => mostrarEditarPago(context, p, a),
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
        // Pie
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate100))),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                if (a.saldo > 0) ...[
                  Expanded(
                    child: Btn(texto: 'Registrar pago', icono: Icons.attach_money, onPressed: () => mostrarRegistrarPago(context, a)),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Btn(
                    texto: 'Editar',
                    icono: Icons.edit_outlined,
                    tipo: BtnTipo.outline,
                    onPressed: () => mostrarFormArreglo(context, editar: a),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
