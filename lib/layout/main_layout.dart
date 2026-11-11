import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/arreglo.dart';
import '../screens/agenda_screen.dart';
import '../screens/arreglos_screen.dart';
import '../screens/clientes_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/domicilios_screen.dart';
import '../screens/informes_screen.dart';
import '../services/auth_service.dart';
import '../state/datos.dart';
import '../theme/app_theme.dart';
import '../utils/formatos.dart';
import '../widgets/ui.dart';

/// Secciones del menú (navItems del sidebar de la web + Domicilios).
enum Seccion {
  dashboard('Dashboard', Icons.dashboard_outlined),
  arreglos('Arreglos', Icons.content_cut),
  agenda('Agenda', Icons.calendar_today_outlined),
  clientes('Clientes', Icons.people_outline),
  domicilios('Domicilios', Icons.delivery_dining_outlined),
  informes('Informes', Icons.bar_chart);

  const Seccion(this.titulo, this.icono);

  final String titulo;
  final IconData icono;
}

/// Permite que una pantalla cambie de sección (p. ej. Dashboard → Agenda de un día).
class Navegacion extends InheritedWidget {
  const Navegacion({super.key, required this.ir, required super.child});

  final void Function(Seccion seccion, {String? fecha, String? arreglo}) ir;

  static Navegacion of(BuildContext context) => context.getInheritedWidgetOfExactType<Navegacion>()!;

  @override
  bool updateShouldNotify(Navegacion oldWidget) => false;
}

/// main-layout de la web en versión celular: topbar blanca + menú lateral navy.
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final _scaffold = GlobalKey<ScaffoldState>();
  Seccion _seccion = Seccion.dashboard;
  // Para abrir la Agenda en un día y con un arreglo desplegado
  String? _fechaAgenda;
  String? _arregloAgenda;
  int _version = 0;

  void _ir(Seccion s, {String? fecha, String? arreglo}) {
    setState(() {
      _seccion = s;
      _fechaAgenda = fecha;
      _arregloAgenda = arreglo;
      _version++;
    });
    _scaffold.currentState?.closeDrawer();
  }

  Widget _pagina() {
    switch (_seccion) {
      case Seccion.dashboard:
        return const DashboardScreen();
      case Seccion.arreglos:
        return const ArreglosScreen();
      case Seccion.agenda:
        return AgendaScreen(key: ValueKey('agenda$_version'), fechaInicial: _fechaAgenda, arregloInicial: _arregloAgenda);
      case Seccion.clientes:
        return const ClientesScreen();
      case Seccion.domicilios:
        return const DomiciliosScreen();
      case Seccion.informes:
        return const InformesScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final esMapa = _seccion == Seccion.domicilios;
    return Navegacion(
      ir: _ir,
      child: Scaffold(
        key: _scaffold,
        backgroundColor: AppColors.slate50,
        drawer: _Sidebar(actual: _seccion, onSelect: _ir),
        body: Column(
          children: [
            _Topbar(titulo: _seccion.titulo, onMenu: () => _scaffold.currentState?.openDrawer()),
            Expanded(
              child: esMapa
                  ? _pagina()
                  : SafeArea(top: false, child: _pagina()),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
//  TOPBAR (.topbar): menú, título navy, campana con arreglos de hoy, avatar cian
// ---------------------------------------------------------------------
class _Topbar extends StatelessWidget {
  const _Topbar({required this.titulo, required this.onMenu});

  final String titulo;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final datos = DatosScope.of(context);
    final hoy = todayKey();
    final deHoy = datos.arreglos.where((a) => a.fechaEntrega == hoy && !a.entregado).toList()
      ..sort((a, b) => (a.horaEntrega ?? '99').compareTo(b.horaEntrega ?? '99'));
    final usuario = FirebaseAuth.instance.currentUser;
    final nombre = usuario?.displayName?.trim().isNotEmpty == true ? usuario!.displayName! : (usuario?.email ?? '');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.slate200)),
        boxShadow: AppShadows.sm,
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(onPressed: onMenu, icon: const Icon(Icons.menu, color: AppColors.slate500)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                ),
                // Campana: arreglos de hoy
                Stack(
                  children: [
                    IconButton(
                      onPressed: () => _panelHoy(context, deHoy.map((a) => a.id).toList()),
                      icon: const Icon(Icons.notifications_none, color: AppColors.slate500),
                    ),
                    if (deHoy.isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.red500, shape: BoxShape.circle),
                          child: Text(
                            '${deHoy.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                // Avatar: menú del usuario
                PopupMenuButton<int>(
                  offset: const Offset(0, 48),
                  color: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate800)),
                          const Text('Administrador', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 1,
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 18, color: AppColors.red600),
                          SizedBox(width: 8),
                          Text('Cerrar Sesión', style: TextStyle(color: AppColors.red600, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (_) => AuthService().cerrarSesion(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.cyan, shape: BoxShape.circle, boxShadow: AppShadows.sm),
                          child: Text(
                            nombre.isEmpty ? '?' : nombre[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 16, color: AppColors.slate400),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// .notif__panel: "Arreglos de Hoy"
  void _panelHoy(BuildContext context, List<String> ids) {
    final nav = Navegacion.of(context);
    final datos = DatosScope.read(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
      clipBehavior: Clip.antiAlias,
      builder: (ctx) {
        final lista = ids.map(datos.arreglo).whereType<Arreglo>().toList();
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                decoration: const BoxDecoration(gradient: kGradienteMarca),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Arreglos de Hoy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            fecha(DateTime.now(), "EEEE d 'de' MMMM", capital: true),
                            style: const TextStyle(color: AppColors.blue100, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white, size: 18)),
                  ],
                ),
              ),
              Flexible(
                child: lista.isEmpty
                    ? const Vacio(texto: 'Sin entregas para hoy')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: lista.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final a = lista[i];
                          return InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              nav.ir(Seccion.agenda, fecha: a.fechaEntrega, arreglo: a.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      StatusBadge(estado: a.estado),
                                      const Spacer(),
                                      Text(
                                        a.horaEntrega != null ? time12(a.horaEntrega) : 'Entrega hoy',
                                        style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(a.nombreCliente, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate800)),
                                  Text(
                                    a.descripcion,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text('ID: ${a.codigo}', style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
                                      const Spacer(),
                                      if (a.saldo > 0)
                                        Text(
                                          'Saldo: ${cop(a.saldo)}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.orange500, fontWeight: FontWeight.w600),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                width: double.infinity,
                color: AppColors.slate50,
                child: SafeArea(
                  top: false,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      nav.ir(Seccion.agenda);
                    },
                    child: const Text('Ver agenda completa →', style: TextStyle(fontSize: 13, color: AppColors.blue)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
//  SIDEBAR (.sidebar): navy, logo arriba, items, Cerrar Sesión abajo
// ---------------------------------------------------------------------
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.actual, required this.onSelect});

  final Seccion actual;
  final void Function(Seccion, {String? fecha, String? arreglo}) onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 288,
      backgroundColor: AppColors.navy,
      shape: const RoundedRectangleBorder(),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.navyDarkest,
              border: Border(bottom: BorderSide(color: AppColors.blue700)),
            ),
            child: const SafeArea(
              bottom: false,
              child: SizedBox(height: 80, child: Center(child: LogoInterfajas(alto: 48))),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              children: [
                for (final s in Seccion.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ItemMenu(
                      icono: s.icono,
                      texto: s.titulo,
                      activo: s == actual,
                      onTap: () => onSelect(s),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.blue700))),
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
            child: SafeArea(
              top: false,
              child: _ItemMenu(
                icono: Icons.logout,
                texto: 'Cerrar Sesión',
                activo: false,
                onTap: () => AuthService().cerrarSesion(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.icono, required this.texto, required this.activo, required this.onTap});

  final IconData icono;
  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? AppColors.blue : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: activo ? 2 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: AppColors.cyan.withValues(alpha: 0.2),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Icon(icono, size: 20, color: activo ? Colors.white : AppColors.blue300),
              const SizedBox(width: 12),
              Text(
                texto,
                style: TextStyle(
                  color: activo ? Colors.white : AppColors.blue100,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
