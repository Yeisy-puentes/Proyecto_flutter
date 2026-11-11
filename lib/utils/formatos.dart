import 'package:intl/intl.dart';

/// Mismos formatos que los pipes de la web (cop, time12) y date.utils.ts.

/// 45000 -> "$45.000"
String cop(num? valor) {
  if (valor == null) return '';
  final signo = valor < 0 ? '-' : '';
  final digitos = valor.round().abs().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      );
  return '$signo\$$digitos';
}

/// "14:30" -> "2:30 p. m."
String time12(String? hora) {
  if (hora == null || hora.isEmpty) return '';
  final partes = hora.split(':');
  final h = int.tryParse(partes[0]);
  final m = partes.length > 1 ? int.tryParse(partes[1]) : 0;
  if (h == null || m == null) return hora;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} ${h >= 12 ? 'p. m.' : 'a. m.'}';
}

/// DateTime -> "2026-11-08" (así se guardan las fechas, igual que en MySQL)
String toDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "2026-11-08" -> DateTime local
DateTime fromDateKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String todayKey() => toDateKey(DateTime.now());

String tomorrowKey() {
  final h = DateTime.now();
  return toDateKey(DateTime(h.year, h.month, h.day + 1));
}

/// TimeOfDay-like "HH:mm" de un DateTime
String toTimeKey(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Formato con intl en español: fecha(d, "EEEE d 'de' MMMM")
String fecha(DateTime d, String patron, {bool capital = false}) {
  final t = DateFormat(patron, 'es').format(d);
  return capital ? _capitalizar(t) : t;
}

/// Atajo: "d MMM y" a partir de una clave yyyy-MM-dd (o '—')
String fechaKey(String? key, [String patron = 'd MMM y']) =>
    key == null || key.isEmpty ? '—' : fecha(fromDateKey(key), patron);

/// Quita tildes y pasa a minúsculas (para buscar)
String normalizar(String s) {
  const con = 'áéíóúüñÁÉÍÓÚÜÑ';
  const sin = 'aeiouunAEIOUUN';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = con.indexOf(ch);
    b.write(i >= 0 ? sin[i] : ch);
  }
  return b.toString().toLowerCase().trim();
}

/// "R001" a partir del número del arreglo
String codigoArreglo(int numero) => 'R${numero.toString().padLeft(3, '0')}';

/// Lee un número escrito con puntos de miles: "45.000" -> 45000
double? leerPesos(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[^0-9]'), '');
  if (limpio.isEmpty) return null;
  return double.parse(limpio);
}
