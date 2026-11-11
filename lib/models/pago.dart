import 'catalogos.dart';

/// Tabla `pagos`: un arreglo tiene varios pagos (abonos), relación 1:N.
class Pago {
  const Pago({
    required this.id,
    required this.idArreglo,
    required this.monto,
    required this.fecha,
    required this.metodo,
  });

  final String id;
  final String idArreglo;
  final double monto;
  final String fecha; // yyyy-MM-dd
  final MetodoPago metodo;

  Map<String, dynamic> toMap() => {
        'idArreglo': idArreglo,
        'monto': monto,
        'fecha': fecha,
        'metodo': metodo.name,
        'creadoEn': DateTime.now().millisecondsSinceEpoch,
      };

  factory Pago.fromMap(String id, Map<String, dynamic> d) => Pago(
        id: id,
        idArreglo: d['idArreglo'] as String? ?? '',
        monto: (d['monto'] as num? ?? 0).toDouble(),
        fecha: d['fecha'] is String ? d['fecha'] as String : '1970-01-01',
        metodo: MetodoPago.desde((d['metodo'] ?? d['tipo']) as String?),
      );
}
