import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tabla `estados` de la web: pendiente, en_proceso, listo, entregado.
enum EstadoArreglo {
  pendiente('Pendiente', Color(0xFFF59E0B)),
  enProceso('En Taller', Color(0xFF3B82F6)),
  listo('Listo', Color(0xFF10B981)),
  entregado('Entregado', Color(0xFF6366F1));

  const EstadoArreglo(this.etiqueta, this.colorGrafica);

  final String etiqueta;

  /// Colores de las gráficas de informes (STATUS_COLORS de la web).
  final Color colorGrafica;

  /// Clave guardada en Firestore (igual a la web: en_proceso)
  String get clave => this == enProceso ? 'en_proceso' : name;

  static EstadoArreglo desde(String? texto) {
    switch (texto) {
      case 'en_proceso':
      case 'enProceso':
        return enProceso;
      case 'listo':
        return listo;
      case 'entregado':
        return entregado;
      default:
        return pendiente;
    }
  }

  // ---- Colores del badge (.badge--*) ----
  Color get fondo => switch (this) {
        pendiente => AppColors.yellow100,
        enProceso => AppColors.blue100,
        listo => AppColors.green100,
        entregado => AppColors.slate100,
      };
  Color get texto => switch (this) {
        pendiente => AppColors.yellow700,
        enProceso => AppColors.blue700,
        listo => AppColors.green700,
        entregado => AppColors.slate700,
      };
  Color get borde => switch (this) {
        pendiente => AppColors.yellow200,
        enProceso => AppColors.blue200,
        listo => AppColors.green200,
        entregado => AppColors.slate200,
      };

  /// .status-dot--*
  Color get punto => switch (this) {
        pendiente => AppColors.yellow400,
        enProceso => AppColors.blue500,
        listo => AppColors.green500,
        entregado => AppColors.slate400,
      };

  IconData get icono => switch (this) {
        pendiente => Icons.error_outline,
        enProceso => Icons.schedule,
        _ => Icons.check_circle_outline,
      };
}

/// Tabla `tipos_pago` de la web.
enum MetodoPago {
  efectivo('Efectivo', Icons.payments_outlined),
  transferencia('Transferencia', Icons.swap_horiz),
  nequi('Nequi', Icons.phone_iphone),
  daviplata('Daviplata', Icons.phone_iphone),
  tarjeta('Tarjeta', Icons.credit_card),
  otro('Otro', Icons.more_horiz);

  const MetodoPago(this.etiqueta, this.icono);

  final String etiqueta;
  final IconData icono;

  /// Los que se pueden elegir al registrar un pago (igual que la web).
  static const seleccionables = [efectivo, tarjeta, transferencia];

  static MetodoPago desde(String? texto) => MetodoPago.values.firstWhere(
        (m) => m.name == texto,
        orElse: () => MetodoPago.otro,
      );

  // .badge--pago-* y .method-chip.is-active--*
  Color get fondo => switch (this) {
        efectivo => AppColors.green100,
        transferencia => AppColors.blue100,
        nequi => AppColors.purple100,
        daviplata => AppColors.red100,
        tarjeta => AppColors.slate100,
        otro => AppColors.orange100,
      };
  Color get texto => switch (this) {
        efectivo => AppColors.green700,
        transferencia => AppColors.blue700,
        nequi => AppColors.purple700,
        daviplata => AppColors.red700,
        tarjeta => AppColors.slate700,
        otro => AppColors.orange700,
      };
  Color get borde => switch (this) {
        efectivo => AppColors.green500,
        transferencia => AppColors.blue500,
        nequi => AppColors.purple500,
        daviplata => AppColors.red500,
        tarjeta => AppColors.slate500,
        otro => AppColors.orange500,
      };
}

/// Colores de recordatorio (blue, green, yellow, red, purple).
enum ColorRecordatorio {
  blue('Azul', AppColors.blue100, AppColors.blue200, AppColors.blue800),
  green('Verde', AppColors.green100, AppColors.green200, AppColors.green800),
  yellow('Amarillo', AppColors.yellow100, AppColors.yellow200, AppColors.yellow800),
  red('Rojo', AppColors.red100, AppColors.red200, AppColors.red800),
  purple('Morado', AppColors.purple100, AppColors.purple200, AppColors.purple800);

  const ColorRecordatorio(this.etiqueta, this.fondo, this.borde, this.texto);

  final String etiqueta;
  final Color fondo;
  final Color borde;
  final Color texto;

  static ColorRecordatorio desde(String? t) => ColorRecordatorio.values.firstWhere(
        (c) => c.name == t,
        orElse: () => ColorRecordatorio.blue,
      );
}
