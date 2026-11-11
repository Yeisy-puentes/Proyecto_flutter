import 'package:flutter/material.dart';

import '../layout/main_layout.dart';
import '../models/arreglo.dart';
import '../models/catalogos.dart';
import '../state/datos.dart';
import '../theme/app_theme.dart';
import '../utils/formatos.dart';
import '../widgets/ui.dart';
import 'cliente_detalle_screen.dart';

enum _Grupo { hoy, manana, listos }

/// Dashboard de la web: 3 tarjetas (Pendientes Hoy / Mañana / Listos) que
/// cambian la lista principal, y "Próximas entregas" (después de mañana).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _Grupo _grupo = _Grupo.hoy;

  /// Por fecha y hora de entrega (sin hora al final)
  static int _porEntrega(Arreglo a, Arreglo b) {
    final f = (a.fechaEntrega ?? '9999').compareTo(b.fechaEntrega ?? '9999');
    return f != 0 ? f : (a.horaEntrega ?? '99:99').compareTo(b.horaEntrega ?? '99:99');
  }

  @override
  Widget build(BuildContext context) {
    final datos = DatosScope.of(context);
    final hoy = todayKey();
    final manana = tomorrowKey();
    final sinEntregar = datos.arreglos.where((a) => !a.entregado).toList()..sort(_porEntrega);

    final grupos = {
      _Grupo.hoy: sinEntregar.where((a) => a.estado == EstadoArreglo.pendiente && a.fechaEntrega == hoy).toList(),
      _Grupo.manana: sinEntregar.where((a) => a.estado == EstadoArreglo.pendiente && a.fechaEntrega == manana).toList(),
      _Grupo.listos: sinEntregar.where((a) => a.estado == EstadoArreglo.listo).toList()
        ..sort((a, b) => _porEntrega(b, a)),
    };
    final proximas = sinEntregar.where((a) => a.fechaEntrega != null && a.fechaEntrega!.compareTo(manana) > 0).toList();

    final (titulo, vacio) = switch (_grupo) {
      _Grupo.hoy => ('Pendientes de hoy', 'No hay arreglos pendientes para entregar hoy.'),
      _Grupo.manana => ('Pendientes de mañana', 'No hay arreglos pendientes para entregar mañana.'),
      _Grupo.listos => ('Listos para recoger', 'No hay arreglos listos esperando al cliente.'),
    };
    final lista = grupos[_grupo]!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Celular: tarjetas en 2 columnas, la tercera a todo el ancho
        Row(
          children: [
            Expanded(
              child: _StatCard(
                titulo: 'Pendientes Hoy',
                valor: grupos[_Grupo.hoy]!.length,
                etiqueta: 'Prioridad',
                icono: Icons.schedule,
                fondoIcono: AppColors.orange50,
                colorIcono: AppColors.orange500,
                activa: _grupo == _Grupo.hoy,
                onTap: () => setState(() => _grupo = _Grupo.hoy),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                titulo: 'Pendientes Mañana',
                valor: grupos[_Grupo.manana]!.length,
                etiqueta: 'Preparar',
                icono: Icons.calendar_today_outlined,
                fondoIcono: AppColors.blue50,
                colorIcono: AppColors.blue600,
                activa: _grupo == _Grupo.manana,
                onTap: () => setState(() => _grupo = _Grupo.manana),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatCard(
          titulo: 'Listos para Recoger',
          valor: grupos[_Grupo.listos]!.length,
          etiqueta: 'Avisar',
          icono: Icons.check_circle_outline,
          fondoIcono: AppColors.green50,
          colorIcono: AppColors.green600,
          activa: _grupo == _Grupo.listos,
          onTap: () => setState(() => _grupo = _Grupo.listos),
        ),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EncabezadoLista(
                titulo: titulo,
                subtitulo: fecha(DateTime.now(), "EEEE d 'de' MMMM", capital: true),
                total: lista.length,
                unidad: lista.length == 1 ? 'arreglo' : 'arreglos',
              ),
              const SizedBox(height: 16),
              if (lista.isEmpty)
                Vacio(texto: datos.cargando ? 'Cargando...' : vacio, icono: Icons.check_circle_outline)
              else
                for (final a in lista) ...[
                  _FilaEntrega(arreglo: a, mostrarFecha: _grupo == _Grupo.listos, aAgenda: _grupo != _Grupo.listos),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EncabezadoLista(titulo: 'Próximas entregas', subtitulo: 'Después de mañana', total: proximas.length),
              const SizedBox(height: 16),
              if (proximas.isEmpty)
                Vacio(
                  texto: datos.cargando ? 'Cargando...' : 'No hay entregas programadas después de mañana.',
                  icono: Icons.calendar_today_outlined,
                )
              else
                for (final a in proximas) ...[
                  _FilaEntrega(arreglo: a, mostrarFecha: true, estrecha: true),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

/// .stat-card--button
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.titulo,
    required this.valor,
    required this.etiqueta,
    required this.icono,
    required this.fondoIcono,
    required this.colorIcono,
    required this.activa,
    required this.onTap,
  });

  final String titulo;
  final int valor;
  final String etiqueta;
  final IconData icono;
  final Color fondoIcono;
  final Color colorIcono;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: activa ? AppColors.blue200 : AppColors.slate100),
        boxShadow: activa
            ? [BoxShadow(color: AppColors.blue500.withValues(alpha: 0.15), spreadRadius: 3), ...AppShadows.md]
            : AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: fondoIcono, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Icon(icono, size: 20, color: colorIcono),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        etiqueta,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.slate600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(titulo, style: const TextStyle(fontSize: 14, color: AppColors.slate500, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('$valor', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EncabezadoLista extends StatelessWidget {
  const _EncabezadoLista({required this.titulo, required this.subtitulo, required this.total, this.unidad});

  final String titulo;
  final String subtitulo;
  final int total;
  final String? unidad;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate800)),
              Text(subtitulo, style: const TextStyle(fontSize: 14, color: AppColors.slate500)),
            ],
          ),
        ),
        Text.rich(
          TextSpan(
            text: '$total',
            children: [
              if (unidad != null)
                TextSpan(
                  text: ' $unidad',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.slate500),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate800),
        ),
      ],
    );
  }
}

/// .delivery-row versión celular: hora/fecha + estado arriba, cliente y descripción, teléfono abajo.
class _FilaEntrega extends StatelessWidget {
  const _FilaEntrega({required this.arreglo, this.mostrarFecha = false, this.estrecha = false, this.aAgenda = false});

  final Arreglo arreglo;
  final bool mostrarFecha;
  final bool estrecha;
  final bool aAgenda;

  @override
  Widget build(BuildContext context) {
    final a = arreglo;
    final cuando = mostrarFecha
        ? (a.fechaEntrega == null ? '—' : fechaKey(a.fechaEntrega, 'd MMM'))
        : (a.horaEntrega != null ? time12(a.horaEntrega) : 'Sin hora');
    final sub = mostrarFecha && a.horaEntrega != null ? time12(a.horaEntrega) : null;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.slate100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (aAgenda) {
            Navegacion.of(context).ir(Seccion.agenda, fecha: a.fechaEntrega, arreglo: a.id);
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ClienteDetalleScreen(idCliente: a.idCliente, arregloAbierto: a.id)),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(10)),
                    child: Text.rich(
                      TextSpan(
                        text: cuando,
                        children: [
                          if (sub != null)
                            TextSpan(text: '  $sub', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
                        ],
                      ),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.blue600),
                    ),
                  ),
                  const Spacer(),
                  StatusBadge(estado: a.estado, compacto: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                a.nombreCliente,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate800),
              ),
              if (!estrecha)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${a.codigo} ',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate400),
                      ),
                      TextSpan(text: a.descripcion.isEmpty ? 'Sin descripción' : a.descripcion),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: AppColors.slate500),
                )
              else
                Text(a.codigo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate400)),
              if (!estrecha && a.telefonoCliente.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 12, color: AppColors.slate500),
                    const SizedBox(width: 4),
                    Text(a.telefonoCliente, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
