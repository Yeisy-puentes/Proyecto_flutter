import 'package:flutter/material.dart';

import '../models/arreglo.dart';
import '../models/catalogos.dart';
import '../models/recordatorio.dart';
import '../state/datos.dart';
import '../theme/app_theme.dart';
import '../utils/formatos.dart';
import '../widgets/ui.dart';

enum _Vista { dia, semana, mes }

/// "Agenda de Entregas" de la web: vistas Día / Semana / Mes con encabezado
/// azul, referencias de colores, tarjetas de arreglo desplegables y recordatorios.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, this.fechaInicial, this.arregloInicial});

  final String? fechaInicial;
  final String? arregloInicial;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late _Vista _vista = widget.fechaInicial != null ? _Vista.dia : _Vista.mes;
  late DateTime _dia = widget.fechaInicial != null ? fromDateKey(widget.fechaInicial!) : _soloFecha(DateTime.now());
  late String? _expandido = widget.arregloInicial;
  String _filtroDia = 'all'; // all | estado.clave | recordatorio

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _lunes(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  void _mover(int sentido) => setState(() {
        switch (_vista) {
          case _Vista.dia:
            _dia = _dia.add(Duration(days: sentido));
          case _Vista.semana:
            _dia = _dia.add(Duration(days: 7 * sentido));
          case _Vista.mes:
            _dia = DateTime(_dia.year, _dia.month + sentido, 1);
        }
      });

  void _abrirDia(DateTime d) => setState(() {
        _dia = d;
        _vista = _Vista.dia;
        _filtroDia = 'all';
      });

  /// Arreglos que se entregan ese día (los entregados no se muestran en la agenda)
  List<Arreglo> _arreglosDe(DatosApp datos, String key) =>
      datos.arreglos.where((a) => a.fechaEntrega == key && !a.entregado).toList()
        ..sort((a, b) => (a.horaEntrega ?? '99').compareTo(b.horaEntrega ?? '99'));

  List<Recordatorio> _recordatoriosDe(DatosApp datos, String key) =>
      datos.recordatorios.where((r) => r.fecha == key).toList()..sort((a, b) => a.hora.compareTo(b.hora));

  @override
  Widget build(BuildContext context) {
    final datos = DatosScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(titulo: 'Agenda de Entregas', subtitulo: 'Calendario de compromisos y recordatorios'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<_Vista>(
                initialValue: _vista,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: const [
                  DropdownMenuItem(value: _Vista.dia, child: Row(children: [Icon(Icons.view_day_outlined, size: 18), SizedBox(width: 8), Text('Día')])),
                  DropdownMenuItem(value: _Vista.semana, child: Row(children: [Icon(Icons.view_week_outlined, size: 18), SizedBox(width: 8), Text('Semana')])),
                  DropdownMenuItem(value: _Vista.mes, child: Row(children: [Icon(Icons.calendar_month_outlined, size: 18), SizedBox(width: 8), Text('Mes')])),
                ],
                onChanged: (v) => setState(() => _vista = v ?? _vista),
              ),
            ),
            const SizedBox(width: 12),
            Btn(texto: 'Recordatorio', icono: Icons.add_alarm, tipo: BtnTipo.cyan, onPressed: () => _nuevoRecordatorio(datos)),
          ],
        ),
        const SizedBox(height: 16),
        // .calendar-card
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.slate200),
            boxShadow: AppShadows.sm,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _navegacion(datos),
              _leyenda(),
              switch (_vista) {
                _Vista.mes => _vistaMes(datos),
                _Vista.semana => _vistaSemana(datos),
                _Vista.dia => _vistaDia(datos),
              },
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- Encabezado azul con flechas ----------------
  Widget _navegacion(DatosApp datos) {
    late String titulo;
    late String sub;
    switch (_vista) {
      case _Vista.mes:
        titulo = fecha(_dia, 'MMMM y', capital: true);
        final n = datos.arreglos.where((a) {
          final f = a.fechaEntrega;
          return f != null && !a.entregado && f.startsWith('${_dia.year}-${_dia.month.toString().padLeft(2, '0')}');
        }).length;
        sub = '$n entregas este mes';
      case _Vista.semana:
        final l = _lunes(_dia);
        final d = l.add(const Duration(days: 6));
        titulo = l.month == d.month
            ? '${l.day} – ${d.day} de ${fecha(d, 'MMMM y')}'
            : '${l.day} ${fecha(l, 'MMM')} – ${d.day} ${fecha(d, 'MMM y')}';
        var n = 0;
        for (var i = 0; i < 7; i++) {
          n += _arreglosDe(datos, toDateKey(l.add(Duration(days: i)))).length;
        }
        sub = '$n ${n == 1 ? 'entrega' : 'entregas'} esta semana';
      case _Vista.dia:
        final k = toDateKey(_dia);
        titulo = fecha(_dia, "EEEE d 'de' MMMM y", capital: true);
        sub = '${_arreglosDe(datos, k).length} entrega(s) · ${_recordatoriosDe(datos, k).length} recordatorio(s)';
    }
    return Container(
      decoration: const BoxDecoration(gradient: kGradienteMarca),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        children: [
          IconButton(onPressed: () => _mover(-1), icon: const Icon(Icons.chevron_left, color: Colors.white)),
          Expanded(
            child: Column(
              children: [
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: _vista == _Vista.mes ? 22 : 17),
                ),
                const SizedBox(height: 2),
                Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.blue100, fontSize: 13)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _dia = _soloFecha(DateTime.now())),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
            child: const Text('Hoy'),
          ),
          IconButton(onPressed: () => _mover(1), icon: const Icon(Icons.chevron_right, color: Colors.white)),
        ],
      ),
    );
  }

  // ---------------- Referencias ----------------
  Widget _leyenda() {
    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [StatusDot(color: c), const SizedBox(width: 6), Text(t, style: const TextStyle(fontSize: 12, color: AppColors.slate600))],
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.slate50,
        border: Border(bottom: BorderSide(color: AppColors.slate200)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'REFERENCIAS:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate500, letterSpacing: 0.6),
          ),
          item(EstadoArreglo.pendiente.punto, 'Pendiente'),
          item(EstadoArreglo.enProceso.punto, 'En Taller'),
          item(EstadoArreglo.listo.punto, 'Listo'),
          item(AppColors.purple400, 'Recordatorio'),
        ],
      ),
    );
  }

  // ---------------- Vista MES ----------------
  Widget _vistaMes(DatosApp datos) {
    final primero = DateTime(_dia.year, _dia.month, 1);
    final inicio = _lunes(primero);
    final hoy = todayKey();
    const letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final semanas = <Widget>[];
    for (var s = 0; s < 6; s++) {
      final celdas = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final dia = inicio.add(Duration(days: s * 7 + d));
        final k = toDateKey(dia);
        final fuera = dia.month != _dia.month;
        final arreglos = _arreglosDe(datos, k);
        final puntos = <Color>{
          for (final a in arreglos) a.estado.punto,
          if (_recordatoriosDe(datos, k).isNotEmpty) AppColors.purple400,
        }.toList();
        celdas.add(
          Expanded(
            child: InkWell(
              onTap: () => _abrirDia(dia),
              child: Container(
                height: 64,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: fuera ? AppColors.slate50 : AppColors.white,
                  border: const Border(
                    right: BorderSide(color: AppColors.slate100),
                    bottom: BorderSide(color: AppColors.slate100),
                  ),
                ),
                child: Opacity(
                  opacity: fuera ? 0.5 : 1,
                  child: Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: k == hoy ? const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle) : null,
                        child: Text(
                          '${dia.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: k == hoy ? Colors.white : (fuera ? AppColors.slate400 : AppColors.slate700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Teléfonos: un punto por estado (máx. 3) y "+N"
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final c in puntos.take(3))
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 1.5), child: StatusDot(color: c, size: 7)),
                          if (puntos.length > 3)
                            Text('+${puntos.length - 3}', style: const TextStyle(fontSize: 9, color: AppColors.slate500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      semanas.add(Row(children: celdas));
    }
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: AppColors.slate50,
            border: Border(bottom: BorderSide(color: AppColors.slate200)),
          ),
          child: Row(
            children: [
              for (final l in letras)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ...semanas,
      ],
    );
  }

  // ---------------- Vista SEMANA ----------------
  Widget _vistaSemana(DatosApp datos) {
    final lunes = _lunes(_dia);
    final hoy = todayKey();
    return Column(
      children: [
        for (var i = 0; i < 7; i++)
          Builder(builder: (context) {
            final dia = lunes.add(Duration(days: i));
            final k = toDateKey(dia);
            final arreglos = _arreglosDe(datos, k);
            final recs = _recordatoriosDe(datos, k);
            final esHoy = k == hoy;
            return InkWell(
              onTap: () => _abrirDia(dia),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: esHoy ? AppColors.blue50 : null,
                  border: const Border(bottom: BorderSide(color: AppColors.slate100)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 48,
                      child: Column(
                        children: [
                          Text(fecha(dia, 'EEE').toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w600)),
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: esHoy ? const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle) : null,
                            child: Text(
                              '${dia.day}',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: esHoy ? Colors.white : AppColors.slate800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: arreglos.isEmpty && recs.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text('Sin eventos', style: TextStyle(fontSize: 13, color: AppColors.slate300)),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final a in arreglos)
                                  _chipEvento(
                                    color: a.estado.punto,
                                    fondo: a.estado.fondo,
                                    texto: '${a.horaEntrega != null ? '${time12(a.horaEntrega)} · ' : ''}${a.nombreCliente}',
                                    onTap: () {
                                      _abrirDia(dia);
                                      setState(() => _expandido = a.id);
                                    },
                                  ),
                                for (final r in recs)
                                  _chipEvento(color: AppColors.purple400, fondo: r.color.fondo, texto: '${time12(r.hora)} · ${r.titulo}'),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _chipEvento({required Color color, required Color fondo, required String texto, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
            child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.slate700)),
          ),
        ),
      ),
    );
  }

  // ---------------- Vista DÍA ----------------
  Widget _vistaDia(DatosApp datos) {
    final k = toDateKey(_dia);
    final arreglos = _arreglosDe(datos, k);
    final recs = _recordatoriosDe(datos, k);

    // Eventos ordenados por hora (los arreglos sin hora van al final)
    final eventos = <(String hora, Object ev)>[
      for (final a in arreglos)
        if (_filtroDia == 'all' || _filtroDia == a.estado.clave) (a.horaEntrega ?? '99:99', a),
      for (final r in recs)
        if (_filtroDia == 'all' || _filtroDia == 'recordatorio') (r.hora, r),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final filtros = <(String, String, Color, int)>[
      for (final e in [EstadoArreglo.pendiente, EstadoArreglo.enProceso, EstadoArreglo.listo])
        if (arreglos.any((a) => a.estado == e)) (e.clave, e.etiqueta, e.punto, arreglos.where((a) => a.estado == e).length),
      if (recs.isNotEmpty) ('recordatorio', 'Recordatorios', AppColors.purple400, recs.length),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                PillBtn(texto: 'Todos', activo: _filtroDia == 'all', onTap: () => setState(() => _filtroDia = 'all')),
                for (final f in filtros) ...[
                  const SizedBox(width: 8),
                  PillBtn(
                    texto: '${f.$2} (${f.$4})',
                    punto: f.$3,
                    activo: _filtroDia == f.$1,
                    onTap: () => setState(() => _filtroDia = f.$1),
                  ),
                ],
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _nuevoRecordatorio(datos),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar recordatorio'),
            ),
          ),
          if (eventos.isEmpty)
            Vacio(
              icono: Icons.event_busy_outlined,
              texto: _filtroDia == 'all' ? 'Sin eventos programados' : 'Sin eventos con este filtro',
              subtexto: _filtroDia == 'all' ? 'No hay entregas ni recordatorios para este día.' : 'Prueba cambiando el filtro.',
            ),
          for (final e in eventos) ...[
            if (e.$2 is Arreglo) _tarjetaArreglo(datos, e.$2 as Arreglo) else _tarjetaRecordatorio(datos, e.$2 as Recordatorio),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  /// .repair-card: resumen siempre visible + detalle desplegable
  Widget _tarjetaArreglo(DatosApp datos, Arreglo a) {
    final abierto = _expandido == a.id;
    final st = a.estado;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: abierto ? AppColors.blue200 : AppColors.slate200),
        boxShadow: abierto ? AppShadows.md : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expandido = abierto ? null : a.id),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, decoration: BoxDecoration(color: st.punto, borderRadius: BorderRadius.circular(9))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 14, color: AppColors.blue),
                              const SizedBox(width: 4),
                              Text(
                                a.horaEntrega != null ? time12(a.horaEntrega) : 'Entrega',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                                decoration: BoxDecoration(
                                  color: st == EstadoArreglo.pendiente ? AppColors.yellow50 : st.fondo.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StatusDot(color: st.punto, size: 6),
                                    const SizedBox(width: 4),
                                    Text(st.etiqueta, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: st.texto)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.nombreCliente,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate800),
                          ),
                          Text(
                            a.descripcion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                    Icon(abierto ? Icons.expand_less : Icons.expand_more, color: AppColors.slate400),
                  ],
                ),
              ),
            ),
          ),
          if (abierto)
            Container(
              color: AppColors.slate50.withValues(alpha: 0.6),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _campo(Icons.person_outline, 'Cliente', a.nombreCliente)),
                      Expanded(child: _campo(Icons.tag, 'ID', a.codigo, color: AppColors.blue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _campo(Icons.attach_money, 'Total', cop(a.valor), negrita: true)),
                      Expanded(child: _campo(null, 'Abonado', cop(a.pagado), color: AppColors.slate500)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _campo(null, 'Descripción', a.descripcion.isEmpty ? '—' : a.descripcion),
                  if (a.valor > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Pago', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
                        const Spacer(),
                        Text(
                          a.saldo <= 0 ? 'Pagado' : 'Pendiente ${cop(a.saldo)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: a.saldo <= 0 ? AppColors.green600 : AppColors.orange500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    BarraPago(porcentaje: a.porcentajePagado),
                  ],
                  if (st == EstadoArreglo.pendiente || st == EstadoArreglo.enProceso) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (st == EstadoArreglo.pendiente) ...[
                          Expanded(
                            child: Btn(
                              texto: 'Pasar a Taller',
                              icono: Icons.content_cut,
                              sm: true,
                              onPressed: () {
                                datos.repo.cambiarEstado(a.id, EstadoArreglo.enProceso);
                                toast(context, '${a.codigo} ahora está "En Taller".');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Btn(
                            texto: 'Marcar Listo',
                            icono: Icons.check_circle_outline,
                            sm: true,
                            tipo: BtnTipo.green,
                            onPressed: () {
                              datos.repo.cambiarEstado(a.id, EstadoArreglo.listo);
                              toast(context, '${a.codigo} está listo para entregar.');
                            },
                          ),
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

  Widget _campo(IconData? icono, String etiqueta, String valor, {Color? color, bool negrita = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icono != null) ...[Icon(icono, size: 12, color: AppColors.slate400), const SizedBox(width: 4)],
              Text(etiqueta, style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
            ],
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: negrita ? FontWeight.bold : FontWeight.w500,
              color: color ?? AppColors.slate800,
            ),
          ),
        ],
      );

  /// .reminder-card--{color}
  Widget _tarjetaRecordatorio(DatosApp datos, Recordatorio r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: r.color.fondo,
        border: Border.all(color: r.color.borde),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_none, size: 16, color: r.color.texto),
              const SizedBox(width: 8),
              Text(time12(r.hora), style: TextStyle(fontWeight: FontWeight.bold, color: r.color.texto)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(999)),
                child: const Text('Recordatorio', style: TextStyle(fontSize: 12, color: AppColors.slate400)),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Eliminar recordatorio',
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.slate400),
                onPressed: () async {
                  final ok = await confirmar(context, titulo: 'Eliminar recordatorio', mensaje: '¿Eliminar "${r.titulo}"?');
                  if (ok) datos.repo.eliminarRecordatorio(r.id);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(r.titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: r.color.texto)),
          if (r.descripcion.isNotEmpty) Text(r.descripcion, style: TextStyle(fontSize: 14, color: r.color.texto)),
        ],
      ),
    );
  }

  // ---------------- Modal: Nuevo Recordatorio ----------------
  Future<void> _nuevoRecordatorio(DatosApp datos) {
    return mostrarModal<void>(
      context,
      titulo: 'Nuevo Recordatorio',
      subtitulo: 'Agrega un recordatorio a la agenda',
      degradado: true,
      cuerpo: (ctx) => _FormRecordatorio(datos: datos, dia: _dia),
    );
  }
}

class _FormRecordatorio extends StatefulWidget {
  const _FormRecordatorio({required this.datos, required this.dia});

  final DatosApp datos;
  final DateTime dia;

  @override
  State<_FormRecordatorio> createState() => _FormRecordatorioState();
}

class _FormRecordatorioState extends State<_FormRecordatorio> {
  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _desc = TextEditingController();
  late String _fecha = toDateKey(widget.dia);
  String _hora = '09:00';
  ColorRecordatorio _color = ColorRecordatorio.blue;

  @override
  void dispose() {
    _titulo.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    widget.datos.repo.crearRecordatorio(
      Recordatorio(id: '', titulo: _titulo.text.trim(), descripcion: _desc.text.trim(), fecha: _fecha, hora: _hora, color: _color),
    );
    Navigator.pop(context);
    toast(context, 'Recordatorio guardado.');
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Campo(
            label: 'Título *',
            child: TextFormField(
              controller: _titulo,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Ej: Llamar cliente, Comprar insumos...'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un título para el recordatorio.' : null,
            ),
          ),
          const SizedBox(height: 16),
          Campo(
            label: 'Descripción',
            child: TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(hintText: 'Detalles adicionales...')),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Campo(
                  label: 'Fecha *',
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: fromDateKey(_fecha),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => _fecha = toDateKey(d));
                    },
                    child: InputDecorator(decoration: const InputDecoration(), child: Text(fechaKey(_fecha, 'dd/MM/y'))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Campo(
                  label: 'Hora *',
                  child: InkWell(
                    onTap: () async {
                      final p = _hora.split(':');
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
                      );
                      if (t != null) {
                        setState(() => _hora = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                      }
                    },
                    child: InputDecorator(decoration: const InputDecoration(), child: Text(time12(_hora))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Campo(
            label: 'Color',
            child: Row(
              children: [
                for (final c in ColorRecordatorio.values)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.fondo,
                        shape: BoxShape.circle,
                        border: Border.all(color: _color == c ? AppColors.navy : c.borde, width: _color == c ? 3 : 1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Btn(texto: 'Cancelar', tipo: BtnTipo.outline, onPressed: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(child: Btn(texto: 'Guardar', tipo: BtnTipo.navy, onPressed: _guardar)),
            ],
          ),
        ],
      ),
    );
  }
}
