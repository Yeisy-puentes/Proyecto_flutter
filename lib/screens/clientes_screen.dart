import 'package:flutter/material.dart';

import '../models/cliente.dart';
import '../state/datos.dart';
import '../theme/app_theme.dart';
import '../utils/formatos.dart';
import '../widgets/formularios.dart';
import '../widgets/ui.dart';
import 'cliente_detalle_screen.dart';

/// "Cartera de Clientes" de la web: buscador y una tarjeta por cliente.
class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _buscar = TextEditingController();

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final datos = DatosScope.of(context);
    final t = normalizar(_buscar.text);
    final lista = datos.clientes
        .where((c) => t.isEmpty || [c.nombre, c.correo, c.cedula, c.telefono].any((v) => normalizar(v).contains(t)))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          titulo: 'Cartera de Clientes',
          subtitulo: 'Base de datos de usuarios registrados',
          accion: Btn(
            texto: 'Nuevo Cliente',
            icono: Icons.person_add_alt,
            full: true,
            onPressed: () => mostrarFormCliente(context),
          ),
        ),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _buscar,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre, correo, cédula o teléfono...',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (lista.isEmpty)
          Vacio(texto: datos.cargando ? 'Cargando clientes...' : 'No se encontraron clientes.')
        else
          for (final c in lista) ...[
            _TarjetaCliente(cliente: c),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

class _TarjetaCliente extends StatelessWidget {
  const _TarjetaCliente({required this.cliente});

  final Cliente cliente;

  Widget _dato(IconData icono, String? etiqueta, String valor, {bool vacio = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icono, size: 16, color: AppColors.slate400),
            const SizedBox(width: 12),
            if (etiqueta != null) Text(etiqueta, style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
            Expanded(
              child: Text(
                valor,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: vacio ? AppColors.slate400 : AppColors.slate600,
                  fontStyle: vacio ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = cliente;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.slate100, shape: BoxShape.circle),
                child: Text(c.inicial, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800, fontSize: 16)),
                    Text('ID: ${c.numero}', style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
                  ],
                ),
              ),
              if (c.ubicacion != null) const Icon(Icons.location_on, color: AppColors.cyan, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          _dato(Icons.badge_outlined, 'CC: ', c.cedula),
          _dato(Icons.mail_outline, null, c.correo.isEmpty ? 'Sin correo' : c.correo, vacio: c.correo.isEmpty),
          _dato(Icons.phone_outlined, null, c.telefono),
          _dato(Icons.place_outlined, null, c.direccion.isEmpty ? 'Sin dirección' : c.direccion, vacio: c.direccion.isEmpty),
          const Divider(height: 24, color: AppColors.slate100),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Btn(
                texto: 'Editar',
                icono: Icons.edit_outlined,
                tipo: BtnTipo.cyan,
                sm: true,
                onPressed: () => mostrarFormCliente(context, cliente: c),
              ),
              const SizedBox(width: 8),
              Btn(
                texto: 'Ver Detalle',
                icono: Icons.visibility_outlined,
                tipo: BtnTipo.navy,
                sm: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ClienteDetalleScreen(idCliente: c.id)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
