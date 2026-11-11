import 'package:flutter/material.dart';

import '../models/arreglo.dart';
import '../models/catalogos.dart';
import '../models/pago.dart';
import '../state/datos.dart';
import '../theme/app_theme.dart';
import '../utils/formatos.dart';
import '../widgets/graficas.dart';
import '../widgets/ui.dart';

enum _Pestana { resumen, ingresos, arreglos, clientes }

enum _Agrupar { dia, semana, mes }

/// "Informes y Reportes" de la web. Los cálculos que antes hacía el backend
/// (/reportes/resumen, ingresos, arreglos, clientes) se hacen aquí con los
/// datos de Firestore, así también funcionan sin internet.
class InformesScreen extends StatefulWidget {
  const InformesScreen({super.key});

  @override
  State<InformesScreen> createState() => _InformesScreenState();
}

class _InformesScreenState extends State<InformesScreen> {
  _Pestana _pestana = _Pestana.resumen;
  _Agrupar _agrupar = _Agrupar.semana;
  late String _desde;
  late String _hasta;
  String _preset = 'month';
  final _buscar = TextEditingController();

  @override
  void initState() {
    super.initState();
    _aplicarPreset('month');
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  void _aplicarPreset(String p) {
    final hoy = DateTime.now();
    setState(() {
      _preset = p;
      _hasta = toDateKey(hoy);
      switch (p) {
        case 'month':
          _desde = toDateKey(DateTime(hoy.year, hoy.month, 1));
          _agrupar = _Agrupar.semana;
        case '3months':
          _desde = toDateKey(DateTime(hoy.year, hoy.month - 2, 1));
          _agrupar = _Agrupar.mes;
        case 'year':
          _desde = toDateKey(DateTime(hoy.year, 1, 1));
          _agrupar = _Agrupar.mes;
      }
    });
  }

  bool _enRango(String f) => f.compareTo(_desde) >= 0 && f.compareTo(_hasta) <= 0;

  /// Clave del período: día, lunes de la semana o mes
  String _periodo(String key) {
    final d = fromDateKey(key);
    return switch (_agrupar) {
      _Agrupar.dia => key,
      _Agrupar.semana => toDateKey(d.subtract(Duration(days: d.weekday - 1))),
      _Agrupar.mes => key.substring(0, 7),
    };
  }

  String _etiquetaPeriodo(String p) => switch (_agrupar) {
        _Agrupar.dia => fechaKey(p, 'd MMM'),
        _Agrupar.semana => fechaKey(p, 'd MMM'),
        _Agrupar.mes => fecha(fromDateKey('$p-01'), 'MMM yy'),
      };

  /// Todos los períodos del rango (para que la gráfica muestre los vacíos en 0)
  List<String> get _periodos {
    final lista = <String>[];
    var d = fromDateKey(_desde);
    final fin = fromDateKey(_hasta);
    while (!d.isAfter(fin)) {
      final p = _periodo(toDateKey(d));
      if (lista.isEmpty || lista.last != p) lista.add(p);
      d = d.add(const Duration(days: 1));
    }
    return lista;
  }

  String get _nombreAgrupar => switch (_agrupar) { _Agrupar.dia => 'día', _Agrupar.semana => 'semana', _Agrupar.mes => 'mes' };

  Future<void> _elegir(bool desde) async {
    final d = await showDatePicker(
      context: context,
      initialDate: fromDateKey(desde ? _desde : _hasta),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      _preset = '';
      if (desde) {
        _desde = toDateKey(d);
      } else {
        _hasta = toDateKey(d);
      }
      if (_desde.compareTo(_hasta) > 0) {
        final t = _desde;
        _desde = _hasta;
        _hasta = t;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final datos = DatosScope.of(context);
    final arreglos = datos.arreglos.where((a) => _enRango(a.fechaIngreso)).toList();
    final pagos = datos.pagos.where((p) => _enRango(p.fecha)).toList();
    final cobrado = pagos.fold<double>(0, (s, p) => s + p.monto);
    final pendiente = arreglos.fold<double>(0, (s, a) => s + (a.saldo > 0 ? a.saldo : 0));
    final clientesActivos = arreglos.map((a) => a.idCliente).toSet().length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(titulo: 'Informes y Reportes', subtitulo: 'Análisis y estadísticas del negocio'),
        const SizedBox(height: 16),
        // ---- Toolbar: fechas, atajos, agrupar y tipo de informe ----
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _fecha('Desde', _desde, () => _elegir(true))),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—', style: TextStyle(color: AppColors.slate400))),
                  Expanded(child: _fecha('Hasta', _hasta, () => _elegir(false))),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PillBtn(texto: 'Este mes', activo: _preset == 'month', onTap: () => _aplicarPreset('month')),
                  PillBtn(texto: '3 meses', activo: _preset == '3months', onTap: () => _aplicarPreset('3months')),
                  PillBtn(texto: 'Este año', activo: _preset == 'year', onTap: () => _aplicarPreset('year')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Agrupar por', style: TextStyle(fontSize: 12, color: AppColors.slate400)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SegmentedButton<_Agrupar>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      segments: const [
                        ButtonSegment(value: _Agrupar.dia, label: Text('Día')),
                        ButtonSegment(value: _Agrupar.semana, label: Text('Semana')),
                        ButtonSegment(value: _Agrupar.mes, label: Text('Mes')),
                      ],
                      selected: {_agrupar},
                      onSelectionChanged: (s) => setState(() => _agrupar = s.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Teléfono: las pestañas en un desplegable
              DropdownButtonFormField<_Pestana>(
                initialValue: _pestana,
                items: const [
                  DropdownMenuItem(value: _Pestana.resumen, child: Row(children: [Icon(Icons.pie_chart_outline, size: 18), SizedBox(width: 8), Text('Resumen General')])),
                  DropdownMenuItem(value: _Pestana.ingresos, child: Row(children: [Icon(Icons.attach_money, size: 18), SizedBox(width: 8), Text('Ingresos')])),
                  DropdownMenuItem(value: _Pestana.arreglos, child: Row(children: [Icon(Icons.content_cut, size: 18), SizedBox(width: 8), Text('Arreglos')])),
                  DropdownMenuItem(value: _Pestana.clientes, child: Row(children: [Icon(Icons.people_outline, size: 18), SizedBox(width: 8), Text('Clientes')])),
                ],
                onChanged: (v) => setState(() {
                  _pestana = v ?? _pestana;
                  _buscar.clear();
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ---- KPI ----
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            _Kpi(Icons.content_cut, AppColors.blue50, AppColors.navy, '${arreglos.length}', 'Arreglos en período'),
            _Kpi(Icons.attach_money, AppColors.green50, AppColors.green700, cop(cobrado), 'Ingresos cobrados'),
            _Kpi(Icons.schedule, AppColors.amber50, AppColors.amber700, cop(pendiente), 'Saldo pendiente'),
            _Kpi(Icons.people_outline, AppColors.cyan50, AppColors.cyan, '$clientesActivos', 'Clientes activos'),
          ],
        ),
        const SizedBox(height: 16),
        ...switch (_pestana) {
          _Pestana.resumen => _resumen(arreglos, pagos),
          _Pestana.ingresos => _ingresos(datos, pagos),
          _Pestana.arreglos => _arreglos(arreglos),
          _Pestana.clientes => _clientes(arreglos),
        },
      ],
    );
  }

  Widget _fecha(String etiqueta, String valor, VoidCallback onTap) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
          const SizedBox(height: 4),
          InkWell(
            onTap: onTap,
            child: InputDecorator(
              decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined, size: 16)),
              child: Text(fechaKey(valor, 'd MMM y'), style: const TextStyle(fontSize: 14)),
            ),
          ),
        ],
      );

  List<PuntoGrafica> _ingresosPorPeriodo(List<Pago> pagos) {
    final suma = <String, double>{};
    for (final p in pagos) {
      final k = _periodo(p.fecha);
      suma[k] = (suma[k] ?? 0) + p.monto;
    }
    return [for (final k in _periodos) PuntoGrafica(_etiquetaPeriodo(k), suma[k] ?? 0)];
  }

  Widget _tituloTarjeta(IconData icono, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Icon(icono, size: 18, color: AppColors.navy),
            const SizedBox(width: 8),
            Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate800))),
          ],
        ),
      );

  // ===== RESUMEN =====
  List<Widget> _resumen(List<Arreglo> arreglos, List<Pago> pagos) {
    final puntos = _ingresosPorPeriodo(pagos);
    final total = puntos.fold<double>(0, (s, p) => s + p.valor);
    // Variación del último período frente al anterior
    String? cambio;
    if (puntos.length >= 2 && puntos[puntos.length - 2].valor > 0) {
      final ult = puntos.last.valor;
      final ant = puntos[puntos.length - 2].valor;
      final pct = ((ult - ant) / ant * 100).round();
      cambio = '${pct > 0 ? '▲' : pct < 0 ? '▼' : ''} ${pct.abs()}%';
    }
    return [
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _tituloTarjeta(Icons.trending_up, 'Ingresos por $_nombreAgrupar')),
              ],
            ),
            Row(
              children: [
                Text(cop(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                if (cambio != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cambio.startsWith('▼') ? AppColors.red100 : AppColors.green100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      cambio,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cambio.startsWith('▼') ? AppColors.red700 : AppColors.green700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            GraficaLinea(puntos: puntos, formato: cop),
          ],
        ),
      ),
      const SizedBox(height: 16),
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tituloTarjeta(Icons.pie_chart_outline, 'Arreglos por estado'),
            GraficaDona(
              segmentos: [
                for (final e in EstadoArreglo.values) (e.etiqueta, arreglos.where((a) => a.estado == e).length, e.colorGrafica),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  // ===== INGRESOS =====
  List<Widget> _ingresos(DatosApp datos, List<Pago> pagos) {
    final t = normalizar(_buscar.text);
    final filas = pagos
        .map((p) => (p, datos.arreglo(p.idArreglo)))
        .where((x) =>
            t.isEmpty ||
            [x.$2?.codigo ?? '', x.$2?.nombreCliente ?? '', x.$1.metodo.etiqueta, fechaKey(x.$1.fecha, 'dd/MM/yy')]
                .any((v) => normalizar(v).contains(t)))
        .toList()
      ..sort((a, b) => b.$1.fecha.compareTo(a.$1.fecha));
    final total = filas.fold<double>(0, (s, x) => s + x.$1.monto);
    return [
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tituloTarjeta(Icons.bar_chart, 'Ingresos por $_nombreAgrupar'),
            const Text('Dinero recibido según la fecha de cada pago.', style: TextStyle(fontSize: 12, color: AppColors.slate400)),
            const SizedBox(height: 12),
            GraficaBarras(puntos: _ingresosPorPeriodo(pagos), formato: (v) => cop(v), color: AppColors.green500),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _tabla(
        titulo: 'Pagos recibidos',
        buscar: 'Buscar por referencia, cliente, método o fecha...',
        vacio: 'Sin pagos en el período.',
        filas: [
          for (final x in filas)
            _FilaInforme(
              arriba: '${fechaKey(x.$1.fecha, 'dd/MM/yy')} · ${x.$2?.codigo ?? '—'}',
              titulo: x.$2?.nombreCliente ?? 'Arreglo eliminado',
              abajo: x.$1.metodo.etiqueta,
              valor: cop(x.$1.monto),
              colorValor: AppColors.green600,
            ),
        ],
        pie: ('${t.isEmpty ? 'Total del período' : 'Total filtrado'}', cop(total)),
      ),
    ];
  }

  // ===== ARREGLOS =====
  List<Widget> _arreglos(List<Arreglo> arreglos) {
    final porPeriodo = <String, int>{};
    for (final a in arreglos) {
      final k = _periodo(a.fechaIngreso);
      porPeriodo[k] = (porPeriodo[k] ?? 0) + 1;
    }
    final t = normalizar(_buscar.text);
    final filas = arreglos
        .where((a) => t.isEmpty || [a.codigo, a.nombreCliente, a.descripcion, a.estado.etiqueta].any((v) => normalizar(v).contains(t)))
        .toList()
      ..sort((a, b) => b.fechaIngreso.compareTo(a.fechaIngreso));
    return [
      Row(
        children: [
          for (final e in EstadoArreglo.values) ...[
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                borderColor: AppColors.slate200,
                child: Column(
                  children: [
                    Text(
                      '${arreglos.where((a) => a.estado == e).length}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: e.colorGrafica),
                    ),
                    Text(e.etiqueta, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                  ],
                ),
              ),
            ),
            if (e != EstadoArreglo.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
      const SizedBox(height: 16),
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tituloTarjeta(Icons.bar_chart, 'Arreglos recibidos por $_nombreAgrupar'),
            GraficaBarras(
              puntos: [for (final k in _periodos) PuntoGrafica(_etiquetaPeriodo(k), (porPeriodo[k] ?? 0).toDouble())],
              formato: (v) => '${v.round()}',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _tabla(
        titulo: 'Listado de arreglos en el período',
        buscar: 'Buscar por referencia, cliente, descripción o estado...',
        vacio: 'Sin arreglos en el período.',
        filas: [
          for (final a in filas)
            _FilaInforme(
              arriba: '${a.codigo} · recibido ${fechaKey(a.fechaIngreso, 'dd/MM/yy')} · entrega ${a.fechaEntrega == null ? '—' : fechaKey(a.fechaEntrega, 'dd/MM/yy')}',
              titulo: a.nombreCliente,
              abajo: a.descripcion,
              pastilla: (a.estado.etiqueta, a.estado.colorGrafica),
            ),
        ],
      ),
    ];
  }

  // ===== CLIENTES =====
  List<Widget> _clientes(List<Arreglo> arreglos) {
    final porCliente = <String, List<Arreglo>>{};
    for (final a in arreglos) {
      porCliente.putIfAbsent(a.idCliente, () => []).add(a);
    }
    final resumen = porCliente.entries.map((e) {
      final l = e.value;
      return (
        nombre: l.first.nombreCliente,
        total: l.length,
        facturado: l.fold<double>(0, (s, a) => s + a.valor),
        cobrado: l.fold<double>(0, (s, a) => s + a.pagado),
        saldo: l.fold<double>(0, (s, a) => s + (a.saldo > 0 ? a.saldo : 0)),
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final t = normalizar(_buscar.text);
    final filas = resumen.where((r) => t.isEmpty || normalizar(r.nombre).contains(t)).toList();
    final totFact = filas.fold<double>(0, (s, r) => s + r.facturado);
    final totCob = filas.fold<double>(0, (s, r) => s + r.cobrado);
    return [
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tituloTarjeta(Icons.emoji_events_outlined, 'Clientes más activos en el período'),
            GraficaBarrasH(items: [for (final r in resumen.take(5)) PuntoGrafica(r.nombre, r.total.toDouble())]),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _tabla(
        titulo: 'Resumen por cliente',
        buscar: 'Buscar cliente...',
        vacio: 'Sin clientes con arreglos en el período.',
        filas: [
          for (final r in filas)
            _FilaInforme(
              arriba: '${r.total} ${r.total == 1 ? 'arreglo' : 'arreglos'} · facturado ${cop(r.facturado)}',
              titulo: r.nombre,
              abajo: 'Cobrado ${cop(r.cobrado)}',
              valor: r.saldo > 0 ? 'Saldo ${cop(r.saldo)}' : 'Al día',
              colorValor: r.saldo > 0 ? AppColors.orange500 : AppColors.slate400,
            ),
        ],
        pie: filas.isEmpty ? null : ('Facturado ${cop(totFact)}', 'Cobrado ${cop(totCob)}'),
      ),
    ];
  }

  /// .table-wrap convertida en lista de tarjetas con buscador
  Widget _tabla({
    required String titulo,
    required String buscar,
    required String vacio,
    required List<Widget> filas,
    (String, String)? pie,
  }) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate200))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate800)),
                const SizedBox(height: 10),
                TextField(
                  controller: _buscar,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(hintText: buscar, prefixIcon: const Icon(Icons.search, size: 20)),
                ),
              ],
            ),
          ),
          if (filas.isEmpty)
            Vacio(texto: _buscar.text.isEmpty ? vacio : 'No se encontraron resultados para «${_buscar.text}»')
          else
            ...filas,
          if (pie != null)
            Container(
              color: AppColors.slate50,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text(pie.$1, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate600))),
                  Text(pie.$2, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.green600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.icono, this.fondo, this.color, this.valor, this.etiqueta);

  final IconData icono;
  final Color fondo;
  final Color color;
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      borderColor: AppColors.slate200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Icon(icono, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(etiqueta, style: const TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.2))),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate800)),
          ),
        ],
      ),
    );
  }
}

class _FilaInforme extends StatelessWidget {
  const _FilaInforme({required this.arriba, required this.titulo, required this.abajo, this.valor, this.colorValor, this.pastilla});

  final String arriba;
  final String titulo;
  final String abajo;
  final String? valor;
  final Color? colorValor;
  final (String, Color)? pastilla;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate100))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(arriba, style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.slate800)),
                Text(abajo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
              ],
            ),
          ),
          if (pastilla != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: pastilla!.$2.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
              child: Text(pastilla!.$1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pastilla!.$2)),
            ),
          if (valor != null) Text(valor!, style: TextStyle(fontWeight: FontWeight.w600, color: colorValor)),
        ],
      ),
    );
  }
}
