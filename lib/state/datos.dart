import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import '../models/arreglo.dart';
import '../models/catalogos.dart';
import '../models/cliente.dart';
import '../models/pago.dart';
import '../models/recordatorio.dart';
import '../services/repositorio.dart';

/// Estado de la app: escucha Firestore en tiempo real (como los services
/// con signals de Angular) y calcula pagado/saldo de cada arreglo.
class DatosApp extends ChangeNotifier {
  DatosApp(this.repo) {
    _subs.addAll([
      repo.flujoClientes().listen((l) => _set(() => clientes = l), onError: _error),
      repo.flujoArreglos().listen((l) => _set(() {
            _arreglosBase = l;
            cargando = false;
          }), onError: _error),
      repo.flujoPagos().listen((l) => _set(() => pagos = l), onError: _error),
      repo.flujoRecordatorios().listen((l) => _set(() => recordatorios = l), onError: _error),
      repo.flujoTaller().listen((t) => _set(() {
            taller = t.punto;
            tallerDireccion = t.direccion;
            tallerCiudad = t.ciudad;
          }), onError: _error),
    ]);
  }

  final Repositorio repo;
  final List<StreamSubscription<dynamic>> _subs = [];

  bool cargando = true;
  String? error;
  List<Cliente> clientes = [];
  List<Pago> pagos = [];
  List<Recordatorio> recordatorios = [];
  LatLng? taller; // punto de la empresa en el mapa
  String tallerDireccion = '';
  String tallerCiudad = 'Neiva';
  List<Arreglo> _arreglosBase = [];
  List<Arreglo>? _arreglosCache;

  void _set(VoidCallback cambio) {
    cambio();
    _arreglosCache = null;
    notifyListeners();
  }

  void _error(Object e) {
    error = '$e';
    cargando = false;
    notifyListeners();
  }

  /// Arreglos con su pagado calculado (pagado = suma de sus pagos).
  List<Arreglo> get arreglos {
    return _arreglosCache ??= () {
      final suma = <String, double>{};
      for (final p in pagos) {
        suma[p.idArreglo] = (suma[p.idArreglo] ?? 0) + p.monto;
      }
      return [for (final a in _arreglosBase) a.conPagado(suma[a.id] ?? 0)];
    }();
  }

  Arreglo? arreglo(String id) {
    for (final a in arreglos) {
      if (a.id == id) return a;
    }
    return null;
  }

  Cliente? cliente(String id) {
    for (final c in clientes) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Arreglo> arreglosDe(String idCliente) =>
      arreglos.where((a) => a.idCliente == idCliente).toList();

  /// Pagos de un arreglo, del más reciente al más antiguo.
  List<Pago> pagosDe(String idArreglo) =>
      pagos.where((p) => p.idArreglo == idArreglo).toList()..sort((a, b) => b.fecha.compareTo(a.fecha));

  /// Método del último pago (badge en la tabla de arreglos).
  MetodoPago? ultimoMetodo(String idArreglo) {
    final l = pagosDe(idArreglo);
    return l.isEmpty ? null : l.first.metodo;
  }

  /// Siguiente número de arreglo/cliente. Se calcula en el teléfono (no con una
  /// transacción) para que también funcione sin internet.
  int get siguienteNumeroArreglo =>
      _arreglosBase.fold<int>(0, (m, a) => a.numero > m ? a.numero : m) + 1;
  int get siguienteNumeroCliente => clientes.fold<int>(0, (m, c) => c.numero > m ? c.numero : m) + 1;

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Pone DatosApp al alcance de todas las pantallas: DatosScope.of(context)
class DatosScope extends InheritedNotifier<DatosApp> {
  const DatosScope({super.key, required DatosApp datos, required super.child}) : super(notifier: datos);

  static DatosApp of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DatosScope>()!.notifier!;

  /// Sin suscribirse a cambios (para usar dentro de callbacks).
  static DatosApp read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DatosScope>()!.notifier!;
}
