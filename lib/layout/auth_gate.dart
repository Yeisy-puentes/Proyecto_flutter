import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../services/repositorio.dart';
import '../state/datos.dart';
import 'main_layout.dart';

/// "Portero" (authGuard de la web): sin sesión muestra el login;
/// con sesión carga los datos de ESA cuenta y muestra la app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final usuario = snap.data;
        if (usuario == null) return const LoginScreen();
        return _ConDatos(key: ValueKey(usuario.uid), uid: usuario.uid);
      },
    );
  }
}

class _ConDatos extends StatefulWidget {
  const _ConDatos({super.key, required this.uid});

  final String uid;

  @override
  State<_ConDatos> createState() => _ConDatosState();
}

class _ConDatosState extends State<_ConDatos> {
  late final DatosApp _datos = DatosApp(Repositorio(widget.uid));

  @override
  void dispose() {
    _datos.dispose();
    super.dispose();
  }

  @override
  // El Navigator va DENTRO de DatosScope: así las pantallas que se abren
  // encima (detalle de cliente, diálogos) también ven los datos.
  Widget build(BuildContext context) => DatosScope(
        datos: _datos,
        child: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const MainLayout()),
        ),
      );
}
