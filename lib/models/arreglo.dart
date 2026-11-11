import '../utils/formatos.dart';
import 'catalogos.dart';

/// Tabla `arreglos` (mismos campos que la web). Las fechas se guardan como
/// texto "yyyy-MM-dd" y las horas como "HH:mm", igual que en MySQL.
/// pagado y saldo NO se guardan: se calculan sumando los pagos.
class Arreglo {
  const Arreglo({
    required this.id,
    required this.numero,
    required this.idCliente,
    required this.nombreCliente,
    required this.cedulaCliente,
    required this.telefonoCliente,
    required this.descripcion,
    required this.estado,
    required this.fechaIngreso,
    this.horaIngreso,
    this.fechaEntrega,
    this.horaEntrega,
    required this.valor,
    this.domicilio = false,
    this.pagado = 0,
  });

  final String id;
  final int numero; // R001, R002...
  final String idCliente;
  final String nombreCliente;
  final String cedulaCliente;
  final String telefonoCliente;
  final String descripcion;
  final EstadoArreglo estado;
  final String fechaIngreso; // yyyy-MM-dd
  final String? horaIngreso; // HH:mm
  final String? fechaEntrega;
  final String? horaEntrega;
  final double valor;
  final bool domicilio; // NUEVO en la app: se entrega en la casa del cliente
  final double pagado; // calculado con los pagos

  String get codigo => codigoArreglo(numero);
  double get saldo => valor - pagado;
  bool get entregado => estado == EstadoArreglo.entregado;

  /// Entregado pero con saldo: se llevó la prenda sin pagar todo.
  bool get conDeuda => entregado && saldo > 0;

  int get porcentajePagado => valor > 0 ? ((pagado / valor) * 100).round().clamp(0, 100) : 0;

  Map<String, dynamic> toMap() => {
        'numero': numero,
        'idCliente': idCliente,
        'nombreCliente': nombreCliente,
        'cedulaCliente': cedulaCliente,
        'telefonoCliente': telefonoCliente,
        'descripcion': descripcion,
        'estado': estado.clave,
        'fechaIngreso': fechaIngreso,
        'horaIngreso': horaIngreso,
        'fechaEntrega': fechaEntrega,
        'horaEntrega': horaEntrega,
        'valor': valor,
        'domicilio': domicilio,
      };

  /// Acepta fechas como texto o (versión anterior de la app) como milisegundos.
  static String? _fecha(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    if (v is num) return toDateKey(DateTime.fromMillisecondsSinceEpoch(v.toInt()));
    return null;
  }

  factory Arreglo.fromMap(String id, Map<String, dynamic> d) => Arreglo(
        id: id,
        numero: (d['numero'] as num? ?? 0).toInt(),
        idCliente: d['idCliente'] as String? ?? '',
        nombreCliente: d['nombreCliente'] as String? ?? '',
        cedulaCliente: d['cedulaCliente'] as String? ?? '',
        telefonoCliente: d['telefonoCliente'] as String? ?? '',
        descripcion: d['descripcion'] as String? ?? '',
        estado: EstadoArreglo.desde(d['estado'] as String?),
        fechaIngreso: _fecha(d['fechaIngreso']) ?? todayKey(),
        horaIngreso: d['horaIngreso'] as String?,
        fechaEntrega: _fecha(d['fechaEntrega']),
        horaEntrega: d['horaEntrega'] as String?,
        valor: (d['valor'] as num? ?? 0).toDouble(),
        domicilio: d['domicilio'] as bool? ?? false,
      );

  Arreglo conPagado(double pagado) => Arreglo(
        id: id,
        numero: numero,
        idCliente: idCliente,
        nombreCliente: nombreCliente,
        cedulaCliente: cedulaCliente,
        telefonoCliente: telefonoCliente,
        descripcion: descripcion,
        estado: estado,
        fechaIngreso: fechaIngreso,
        horaIngreso: horaIngreso,
        fechaEntrega: fechaEntrega,
        horaEntrega: horaEntrega,
        valor: valor,
        domicilio: domicilio,
        pagado: pagado,
      );
}
