import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Gráficas de Informes (line-chart, donut-chart, bar-chart, hbar-chart de la web)
// dibujadas con CustomPaint, sin paquetes extra.

class PuntoGrafica {
  const PuntoGrafica(this.etiqueta, this.valor);

  final String etiqueta;
  final double valor;
}

/// Línea con área (Ingresos por período)
class GraficaLinea extends StatelessWidget {
  const GraficaLinea({super.key, required this.puntos, required this.formato});

  final List<PuntoGrafica> puntos;
  final String Function(double) formato;

  @override
  Widget build(BuildContext context) {
    if (puntos.isEmpty) return const _SinDatos();
    return SizedBox(
      height: 200,
      child: CustomPaint(painter: _LineaPainter(puntos, formato), size: Size.infinite),
    );
  }
}

class _LineaPainter extends CustomPainter {
  _LineaPainter(this.puntos, this.formato);

  final List<PuntoGrafica> puntos;
  final String Function(double) formato;

  @override
  void paint(Canvas canvas, Size size) {
    const izq = 8.0, abajo = 22.0, arriba = 12.0;
    final ancho = size.width - izq * 2;
    final alto = size.height - abajo - arriba;
    final maximo = math.max(1.0, puntos.map((p) => p.valor).reduce(math.max));
    final guia = Paint()
      ..color = AppColors.slate100
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = arriba + alto * i / 3;
      canvas.drawLine(Offset(izq, y), Offset(size.width - izq, y), guia);
    }
    Offset pos(int i) => Offset(
          izq + (puntos.length == 1 ? ancho / 2 : ancho * i / (puntos.length - 1)),
          arriba + alto * (1 - puntos[i].valor / maximo),
        );
    final linea = Path()..moveTo(pos(0).dx, pos(0).dy);
    for (var i = 1; i < puntos.length; i++) {
      linea.lineTo(pos(i).dx, pos(i).dy);
    }
    final area = Path.from(linea)
      ..lineTo(pos(puntos.length - 1).dx, arriba + alto)
      ..lineTo(pos(0).dx, arriba + alto)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.blue.withValues(alpha: 0.25), AppColors.blue.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, arriba, size.width, alto)),
    );
    canvas.drawPath(
      linea,
      Paint()
        ..color = AppColors.blue
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    final cada = (puntos.length / 6).ceil();
    for (var i = 0; i < puntos.length; i++) {
      canvas.drawCircle(pos(i), 3.5, Paint()..color = AppColors.white);
      canvas.drawCircle(
        pos(i),
        3.5,
        Paint()
          ..color = AppColors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (i % cada == 0 || i == puntos.length - 1) {
        _texto(canvas, puntos[i].etiqueta, Offset(pos(i).dx, size.height - 16), centrado: true);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineaPainter old) => old.puntos != puntos;
}

void _texto(Canvas canvas, String t, Offset o, {bool centrado = false, Color color = AppColors.slate400, double tam = 10}) {
  final tp = TextPainter(
    text: TextSpan(text: t, style: TextStyle(color: color, fontSize: tam)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, centrado ? o - Offset(tp.width / 2, 0) : o);
}

class _SinDatos extends StatelessWidget {
  const _SinDatos();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 120,
        child: Center(child: Text('Sin datos en el período', style: TextStyle(color: AppColors.slate400))),
      );
}

/// Barras verticales (Ingresos / Arreglos por período)
class GraficaBarras extends StatelessWidget {
  const GraficaBarras({super.key, required this.puntos, required this.formato, this.color = AppColors.blue});

  final List<PuntoGrafica> puntos;
  final String Function(double) formato;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (puntos.isEmpty) return const _SinDatos();
    final maximo = math.max(1.0, puntos.map((p) => p.valor).reduce(math.max));
    return SizedBox(
      height: 220,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 80),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final p in puntos)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(p.valor > 0 ? formato(p.valor) : '', style: const TextStyle(fontSize: 9, color: AppColors.slate500)),
                      const SizedBox(height: 4),
                      Container(
                        width: 28,
                        height: math.max(2, 150 * p.valor / maximo),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(p.etiqueta, style: const TextStyle(fontSize: 10, color: AppColors.slate500)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dona (Arreglos por estado)
class GraficaDona extends StatelessWidget {
  const GraficaDona({super.key, required this.segmentos});

  final List<(String etiqueta, int valor, Color color)> segmentos;

  @override
  Widget build(BuildContext context) {
    final total = segmentos.fold<int>(0, (s, e) => s + e.$2);
    if (total == 0) return const _SinDatos();
    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(size: const Size(140, 140), painter: _DonaPainter(segmentos, total)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$total', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                  const Text('arreglos', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in segmentos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: s.$3, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.$1, style: const TextStyle(fontSize: 13, color: AppColors.slate600))),
                      Text('${s.$2}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800)),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${(s.$2 * 100 / total).round()}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonaPainter extends CustomPainter {
  _DonaPainter(this.segmentos, this.total);

  final List<(String, int, Color)> segmentos;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    var inicio = -math.pi / 2;
    for (final s in segmentos) {
      if (s.$2 == 0) continue;
      final barrido = 2 * math.pi * s.$2 / total;
      canvas.drawArc(
        rect,
        inicio,
        barrido,
        false,
        Paint()
          ..color = s.$3
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18,
      );
      inicio += barrido;
    }
  }

  @override
  bool shouldRepaint(covariant _DonaPainter old) => true;
}

/// Barras horizontales (Clientes más activos)
class GraficaBarrasH extends StatelessWidget {
  const GraficaBarrasH({super.key, required this.items});

  final List<PuntoGrafica> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _SinDatos();
    final maximo = math.max(1.0, items.map((p) => p.valor).reduce(math.max));
    return Column(
      children: [
        for (final p in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.etiqueta, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.slate700)),
                    ),
                    Text('${p.valor.round()}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: p.valor / maximo,
                    minHeight: 10,
                    backgroundColor: AppColors.slate100,
                    color: AppColors.cyan,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
