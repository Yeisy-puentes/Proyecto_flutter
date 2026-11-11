import 'catalogos.dart';

/// Tabla `recordatorios` (titulo, descripcion, fecha, hora, color).
class Recordatorio {
  const Recordatorio({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    required this.fecha,
    required this.hora,
    required this.color,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final String fecha; // yyyy-MM-dd
  final String hora; // HH:mm
  final ColorRecordatorio color;

  Map<String, dynamic> toMap() => {
        'titulo': titulo,
        'descripcion': descripcion,
        'fecha': fecha,
        'hora': hora,
        'color': color.name,
      };

  factory Recordatorio.fromMap(String id, Map<String, dynamic> d) => Recordatorio(
        id: id,
        titulo: d['titulo'] as String? ?? '',
        descripcion: d['descripcion'] as String? ?? '',
        fecha: d['fecha'] is String ? d['fecha'] as String : '1970-01-01',
        hora: d['hora'] is String ? d['hora'] as String : '08:00',
        color: ColorRecordatorio.desde(d['color'] as String?),
      );
}
