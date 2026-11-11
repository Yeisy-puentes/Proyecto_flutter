import 'package:flutter/material.dart';

import '../models/catalogos.dart';
import '../theme/app_theme.dart';

// =====================================================================
//  Componentes compartidos: equivalen a las clases de 05-components.css
//  y 06-tables-modals.css de la app web.
// =====================================================================

/// .badge--{estado} con su ícono (app-status-badge)
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.estado, this.compacto = false});

  final EstadoArreglo estado;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compacto ? 8 : 12, vertical: compacto ? 2 : 4),
      decoration: BoxDecoration(
        color: estado.fondo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: estado.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compacto) ...[
            Icon(estado.icono, size: 14, color: estado.texto),
            const SizedBox(width: 6),
          ],
          Text(
            estado.etiqueta,
            style: TextStyle(color: estado.texto, fontSize: compacto ? 11 : 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// .badge--pago-{metodo}
class MetodoBadge extends StatelessWidget {
  const MetodoBadge({super.key, required this.metodo, this.sm = false});

  final MetodoPago metodo;
  final bool sm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: sm ? 6 : 12, vertical: sm ? 1 : 4),
      decoration: BoxDecoration(
        color: metodo.fondo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: metodo.fondo == AppColors.slate100 ? AppColors.slate200 : metodo.fondo),
      ),
      child: Text(
        metodo.etiqueta,
        style: TextStyle(color: metodo.texto, fontSize: sm ? 10.5 : 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// .status-dot
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// .card (fondo blanco, radio 16, borde slate-100, sombra sm)
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderColor = AppColors.slate100,
    this.color = AppColors.white,
    this.onTap,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final Color color;
  final VoidCallback? onTap;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.xl);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: borderColor),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// .section-header: título navy 24 bold + subtítulo + botón (en celular, botón a todo el ancho)
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.titulo, required this.subtitulo, this.accion});

  final String titulo;
  final String subtitulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
        Text(
          subtitulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.slate500),
        ),
        if (accion != null) ...[const SizedBox(height: 16), accion!],
      ],
    );
  }
}

enum BtnTipo { primary, navy, cyan, green, emerald, ghost, outline, danger }

/// .btn y sus variantes (.btn--primary, --navy, --cyan, --green, --ghost, --outline)
class Btn extends StatelessWidget {
  const Btn({
    super.key,
    required this.texto,
    this.icono,
    this.onPressed,
    this.tipo = BtnTipo.primary,
    this.sm = false,
    this.full = false,
    this.cargando = false,
  });

  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final BtnTipo tipo;
  final bool sm;
  final bool full;
  final bool cargando;

  (Color, Color, BorderSide?) get _colores => switch (tipo) {
        BtnTipo.primary => (AppColors.blue, AppColors.white, null),
        BtnTipo.navy => (AppColors.navy, AppColors.white, null),
        BtnTipo.cyan => (AppColors.cyan, AppColors.white, null),
        BtnTipo.green => (AppColors.green600, AppColors.white, null),
        BtnTipo.emerald => (AppColors.emerald600, AppColors.white, null),
        BtnTipo.danger => (AppColors.red600, AppColors.white, null),
        BtnTipo.ghost => (Colors.transparent, AppColors.slate600, null),
        BtnTipo.outline => (AppColors.white, AppColors.slate700, const BorderSide(color: AppColors.slate300, width: 2)),
      };

  @override
  Widget build(BuildContext context) {
    final (fondo, texto_, borde) = _colores;
    final hijo = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (cargando)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: texto_),
          )
        else if (icono != null)
          Icon(icono, size: sm ? 16 : 20),
        if (cargando || icono != null) const SizedBox(width: 8),
        Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
      ],
    );
    final boton = TextButton(
      onPressed: cargando ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: fondo,
        foregroundColor: texto_,
        disabledBackgroundColor: fondo == Colors.transparent ? null : fondo.withValues(alpha: 0.7),
        disabledForegroundColor: texto_.withValues(alpha: 0.8),
        padding: sm ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6) : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        minimumSize: Size(0, sm ? 34 : 44),
        textStyle: TextStyle(fontSize: sm ? 14 : 16, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: borde ?? BorderSide.none,
        ),
        elevation: 0,
      ),
      child: hijo,
    );
    return full ? SizedBox(width: double.infinity, child: boton) : boton;
  }
}

/// .btn--icon .btn--ghost
class IconBtn extends StatelessWidget {
  const IconBtn({super.key, required this.icono, required this.onPressed, this.tooltip, this.color = AppColors.slate600});

  final IconData icono;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icono, size: 20, color: color),
        style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
      );
}

/// .field: label (14, medium, slate-700) + control
class Campo extends StatelessWidget {
  const Campo({super.key, required this.label, required this.child, this.hint, this.opcional = false});

  final String label;
  final Widget child;
  final String? hint;
  final bool opcional;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (opcional)
                const TextSpan(
                  text: ' (opcional)',
                  style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.w400),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.slate700),
        ),
        const SizedBox(height: 8),
        child,
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
        ],
      ],
    );
  }
}

/// .progress-bar (azul, verde completo, rojo con deuda)
class BarraPago extends StatelessWidget {
  const BarraPago({super.key, required this.porcentaje, this.deuda = false});

  final int porcentaje;
  final bool deuda;

  @override
  Widget build(BuildContext context) {
    final color = deuda
        ? AppColors.red500
        : porcentaje >= 100
            ? AppColors.green500
            : AppColors.blue500;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: porcentaje / 100,
        minHeight: 6,
        backgroundColor: AppColors.slate100,
        color: color,
      ),
    );
  }
}

/// .pill-btn (filtros redondos) con contador opcional
class PillBtn extends StatelessWidget {
  const PillBtn({super.key, required this.texto, required this.activo, required this.onTap, this.contador, this.punto});

  final String texto;
  final bool activo;
  final VoidCallback onTap;
  final int? contador;
  final Color? punto;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? AppColors.navy : AppColors.white,
      shape: StadiumBorder(side: BorderSide(color: activo ? AppColors.navy : AppColors.slate200)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (punto != null) ...[
                StatusDot(color: activo ? Colors.white70 : punto!),
                const SizedBox(width: 6),
              ],
              Text(
                texto,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: activo ? AppColors.white : AppColors.slate600,
                ),
              ),
              if (contador != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: activo ? Colors.white24 : AppColors.slate100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$contador',
                    style: TextStyle(fontSize: 12, color: activo ? AppColors.white : AppColors.slate600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// app-payment-method-selector (.method-chip)
class SelectorMetodoPago extends StatelessWidget {
  const SelectorMetodoPago({super.key, required this.valor, required this.onChanged});

  final MetodoPago valor;
  final ValueChanged<MetodoPago> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final m in MetodoPago.seleccionables) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: valor == m ? m.fondo : AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: valor == m ? m.borde : AppColors.slate200, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(m.icono, size: 16, color: valor == m ? m.texto : AppColors.slate600),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        m.etiqueta,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: valor == m ? m.texto : AppColors.slate600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (m != MetodoPago.seleccionables.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// Mensaje vacío (.empty-state)
class Vacio extends StatelessWidget {
  const Vacio({super.key, required this.texto, this.icono, this.subtexto});

  final String texto;
  final String? subtexto;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          if (icono != null) ...[Icon(icono, size: 40, color: AppColors.slate300), const SizedBox(height: 12)],
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate500, fontSize: 14)),
          if (subtexto != null)
            Text(subtexto!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate400, fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
//  Modal (.modal-overlay + .modal): diálogo blanco, radio 20, encabezado
// ---------------------------------------------------------------------
Future<T?> mostrarModal<T>(
  BuildContext context, {
  required String titulo,
  String? subtitulo,
  IconData? icono,
  bool degradado = false,
  required Widget Function(BuildContext ctx) cuerpo,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: false,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              decoration: BoxDecoration(
                gradient: degradado ? kGradienteMarca : null,
                border: degradado ? null : const Border(bottom: BorderSide(color: AppColors.slate100)),
              ),
              child: Row(
                children: [
                  if (icono != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.cyan, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Icon(icono, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: degradado ? Colors.white : AppColors.navy,
                          ),
                        ),
                        if (subtitulo != null)
                          Text(
                            subtitulo,
                            style: TextStyle(fontSize: 14, color: degradado ? AppColors.blue100 : AppColors.slate500),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: Icon(Icons.close, color: degradado ? Colors.white : AppColors.slate400),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: cuerpo(ctx),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// .modal__footer: Cancelar (ghost) + acción
class PieModal extends StatelessWidget {
  const PieModal({
    super.key,
    required this.textoAccion,
    required this.onAccion,
    this.tipo = BtnTipo.primary,
    this.cargando = false,
  });

  final String textoAccion;
  final VoidCallback onAccion;
  final BtnTipo tipo;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: Btn(texto: 'Cancelar', tipo: BtnTipo.ghost, onPressed: () => Navigator.of(context).pop())),
          const SizedBox(width: 12),
          Expanded(child: Btn(texto: textoAccion, tipo: tipo, onPressed: onAccion, cargando: cargando)),
        ],
      ),
    );
  }
}

/// app-confirm-dialog. tono: 'danger' (rojo) o 'warning' (naranja)
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String confirmar = 'Eliminar',
  bool peligro = true,
}) async {
  final r = await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: peligro ? AppColors.red100 : AppColors.orange100, shape: BoxShape.circle),
        child: Icon(
          peligro ? Icons.delete_outline : Icons.warning_amber_rounded,
          color: peligro ? AppColors.red600 : AppColors.orange500,
        ),
      ),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800, fontSize: 18)),
      content: Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate600)),
      actions: [
        Row(
          children: [
            Expanded(child: Btn(texto: 'Cancelar', tipo: BtnTipo.outline, onPressed: () => Navigator.of(ctx).pop(false))),
            const SizedBox(width: 12),
            Expanded(
              child: Btn(
                texto: confirmar,
                tipo: peligro ? BtnTipo.danger : BtnTipo.primary,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return r ?? false;
}

/// app-toast: verde (éxito) o rojo (error)
void toast(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(texto)),
          ],
        ),
        backgroundColor: error ? AppColors.red600 : AppColors.green600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
}

/// Logo de Interfajas (mismo diseño que logo-interfajas.svg):
/// "Interfajas" blanco en itálica sobre una franja cian con "ROHYNS STELLA".
class LogoInterfajas extends StatelessWidget {
  const LogoInterfajas({super.key, this.alto = 48});

  final double alto;

  @override
  Widget build(BuildContext context) {
    // Proporciones del SVG original (viewBox 620 x 240)
    final escala = alto / 240;
    return SizedBox(
      height: alto,
      width: 620 * escala,
      child: FittedBox(
        child: SizedBox(
          width: 620,
          height: 240,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 176,
                child: Container(
                  width: 602,
                  height: 50,
                  decoration: BoxDecoration(color: AppColors.cyan, borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.only(left: 22),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'ROHYNS STELLA',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 6,
                top: 18,
                child: Text(
                  'Interfajas',
                  style: TextStyle(
                    fontSize: 112,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
