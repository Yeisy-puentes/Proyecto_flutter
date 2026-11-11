import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import '../models/arreglo.dart';
import '../models/catalogos.dart';
import '../models/cliente.dart';
import '../models/pago.dart';
import '../models/recordatorio.dart';

/// Todas las lecturas y escrituras en Firestore (reemplaza al backend Node + MySQL).
/// Ruta: usuarios/{uid}/clientes | arreglos | pagos | recordatorios | ajustes
/// Lo protegen las mismas reglas del taller: cada cuenta solo ve su carpeta.
///
/// Las escrituras NO se esperan con "await" para confirmar con el servidor:
/// Firestore las guarda primero en el teléfono, así la app funciona sin internet
/// y sube los cambios cuando vuelve la conexión.
class Repositorio {
  Repositorio(this.uid);

  final String uid;

  static Repositorio get actual => Repositorio(FirebaseAuth.instance.currentUser!.uid);

  DocumentReference<Map<String, dynamic>> get _usuario =>
      FirebaseFirestore.instance.collection('usuarios').doc(uid);

  CollectionReference<Map<String, dynamic>> get clientes => _usuario.collection('clientes');
  CollectionReference<Map<String, dynamic>> get arreglos => _usuario.collection('arreglos');
  CollectionReference<Map<String, dynamic>> get pagos => _usuario.collection('pagos');
  CollectionReference<Map<String, dynamic>> get recordatorios => _usuario.collection('recordatorios');
  DocumentReference<Map<String, dynamic>> get taller => _usuario.collection('ajustes').doc('taller');

  // ---------- Flujos en tiempo real ----------
  Stream<List<Cliente>> flujoClientes() => clientes.snapshots().map(
        (q) => q.docs.map((d) => Cliente.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())),
      );

  Stream<List<Arreglo>> flujoArreglos() =>
      arreglos.snapshots().map((q) => q.docs.map((d) => Arreglo.fromMap(d.id, d.data())).toList());

  Stream<List<Pago>> flujoPagos() =>
      pagos.snapshots().map((q) => q.docs.map((d) => Pago.fromMap(d.id, d.data())).toList());

  Stream<List<Recordatorio>> flujoRecordatorios() => recordatorios
      .snapshots()
      .map((q) => q.docs.map((d) => Recordatorio.fromMap(d.id, d.data())).toList());

  /// Ubicación y dirección de la empresa (Interfajas)
  Stream<({LatLng? punto, String direccion, String ciudad})> flujoTaller() => taller.snapshots().map((doc) {
        final d = doc.data();
        final lat = d?['lat'] as num?;
        final lng = d?['lng'] as num?;
        return (
          punto: lat == null || lng == null ? null : LatLng(lat.toDouble(), lng.toDouble()),
          direccion: d?['direccion'] as String? ?? '',
          ciudad: d?['ciudad'] as String? ?? 'Neiva',
        );
      });

  // ---------- Clientes ----------
  /// Devuelve el id del documento (sirve para seleccionarlo enseguida).
  String crearCliente(Cliente c) {
    final ref = clientes.doc();
    ref.set({...c.toMap(), 'creadoEn': DateTime.now().millisecondsSinceEpoch});
    return ref.id;
  }

  /// Actualiza el cliente y su nombre/cédula/teléfono copiados en sus arreglos.
  void actualizarCliente(Cliente c, List<Arreglo> susArreglos) {
    final lote = FirebaseFirestore.instance.batch();
    lote.update(clientes.doc(c.id), c.toMap());
    for (final a in susArreglos) {
      lote.update(arreglos.doc(a.id), {
        'nombreCliente': c.nombre,
        'cedulaCliente': c.cedula,
        'telefonoCliente': c.telefono,
      });
    }
    lote.commit();
  }

  void eliminarCliente(String id) => clientes.doc(id).delete();

  /// Guarda solo el punto del mapa del cliente.
  void fijarUbicacionCliente(String id, LatLng p, {required bool aproximada}) => clientes.doc(id).update({
        'lat': p.latitude,
        'lng': p.longitude,
        'ubicacionAproximada': aproximada,
      });

  // ---------- Arreglos ----------
  /// Crea el arreglo y, si hay abono inicial, el pago (en un solo lote, como la transacción del backend).
  void crearArreglo(Arreglo a, {double abono = 0, MetodoPago? metodo}) {
    final lote = FirebaseFirestore.instance.batch();
    final ref = arreglos.doc();
    lote.set(ref, {...a.toMap(), 'creadoEn': DateTime.now().millisecondsSinceEpoch});
    if (abono > 0) {
      lote.set(
        pagos.doc(),
        Pago(id: '', idArreglo: ref.id, monto: abono, fecha: a.fechaIngreso, metodo: metodo ?? MetodoPago.efectivo)
            .toMap(),
      );
    }
    lote.commit();
  }

  void actualizarArreglo(Arreglo a) => arreglos.doc(a.id).update(a.toMap());

  void cambiarEstado(String idArreglo, EstadoArreglo estado) =>
      arreglos.doc(idArreglo).update({'estado': estado.clave});

  /// Elimina el arreglo y todos sus pagos.
  void eliminarArreglo(String idArreglo, List<Pago> susPagos) {
    final lote = FirebaseFirestore.instance.batch();
    for (final p in susPagos) {
      lote.delete(pagos.doc(p.id));
    }
    lote.delete(arreglos.doc(idArreglo));
    lote.commit();
  }

  // ---------- Pagos ----------
  void registrarPago(Pago p) => pagos.add(p.toMap());

  void actualizarPago(Pago p) => pagos.doc(p.id).update({
        'monto': p.monto,
        'fecha': p.fecha,
        'metodo': p.metodo.name,
      });

  void eliminarPago(String id) => pagos.doc(id).delete();

  // ---------- Recordatorios ----------
  void crearRecordatorio(Recordatorio r) => recordatorios.add(r.toMap());

  void eliminarRecordatorio(String id) => recordatorios.doc(id).delete();

  // ---------- Taller ----------
  void fijarTaller(LatLng p, {String? direccion, String? ciudad}) => taller.set({
        'lat': p.latitude,
        'lng': p.longitude,
        if (direccion != null) 'direccion': direccion,
        if (ciudad != null) 'ciudad': ciudad,
      }, SetOptions(merge: true));
}
