import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

enum _Vista { login, registro, olvido, enviado }

/// Login de la web: fondo degradado azul con ondas, tarjeta con encabezado
/// azul (logo) y una hoja blanca superpuesta con el formulario.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _auth = AuthService();
  _Vista _vista = _Vista.login;
  bool _verClave = false;
  bool _cargando = false;
  String _error = '';

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  void _cambiar(_Vista v) => setState(() {
        _vista = v;
        _error = '';
        _verClave = false;
      });

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = '';
    });
    try {
      switch (_vista) {
        case _Vista.login:
          await _auth.iniciarSesion(_correo.text, _clave.text);
        case _Vista.registro:
          await _auth.registrar(_nombre.text, _correo.text, _clave.text);
        case _Vista.olvido:
          await _auth.recuperarClave(_correo.text);
          if (mounted) setState(() => _vista = _Vista.enviado);
        case _Vista.enviado:
          break;
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String? _validarCorreo(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Este campo es obligatorio.';
    if (!t.contains('@') || !t.contains('.')) return 'Ingresa un correo válido.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final (titulo, subtitulo, boton, cargandoTxt) = switch (_vista) {
      _Vista.login => ('Bienvenido', 'Ingresa con tu cuenta para continuar', 'Iniciar Sesión', 'Ingresando...'),
      _Vista.registro => ('Crear cuenta', 'Registra el usuario administrador del taller', 'Crear cuenta', 'Creando...'),
      _Vista.olvido => (
          'Recuperar contraseña',
          'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una nueva contraseña.',
          'Enviar enlace',
          'Enviando...'
        ),
      _Vista.enviado => ('Revisa tu correo', '', 'Volver a iniciar sesión', ''),
    };

    return Scaffold(
      body: Container(
        // .login-page: degradado 135°
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.loginDeep, AppColors.blue, AppColors.blue200, AppColors.loginLight],
            stops: [0, 0.38, 0.75, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _OndasFondo())),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x730B3FB8), blurRadius: 80, spreadRadius: -20, offset: Offset(0, 40)),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _encabezado(),
                          // Hoja blanca que sube sobre el encabezado
                          Transform.translate(
                            offset: const Offset(0, -24),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                                    child: Column(
                                      children: [
                                        Text(
                                          titulo,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy),
                                        ),
                                        const SizedBox(height: 4),
                                        if (_vista == _Vista.enviado)
                                          Text.rich(
                                            TextSpan(children: [
                                              const TextSpan(text: 'Si '),
                                              TextSpan(text: _correo.text.trim(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                              const TextSpan(text: ' está registrado, te enviamos un enlace para restablecer la contraseña.'),
                                            ]),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 14, color: AppColors.slate500),
                                          )
                                        else
                                          Text(
                                            subtitulo,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 14, color: AppColors.slate500),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                                    child: _vista == _Vista.enviado ? _enviado() : _formulario(boton, cargandoTxt),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '© ${DateTime.now().year} Interfajas. Todos los derechos reservados.',
                                      style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// .login-card__header: azul con logo, línea y texto
  Widget _encabezado() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blueDark, AppColors.loginDeep],
        ),
      ),
      child: Column(
        children: [
          const LogoInterfajas(alto: 80),
          const SizedBox(height: 16),
          Container(
            width: 48,
            height: 2,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(9)),
          ),
          const SizedBox(height: 12),
          Text(
            'Sistema de Gestión de Arreglos Textiles',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String hint, IconData icono, {Widget? sufijo}) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icono, size: 20),
        suffixIcon: sufijo,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  Widget _formulario(String boton, String cargandoTxt) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_vista == _Vista.registro) ...[
            Campo(
              label: 'Nombre completo',
              child: TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: _deco('Ej: Rohyns Stella', Icons.badge_outlined),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Este campo es obligatorio.' : null,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Campo(
            label: 'Correo Electrónico',
            child: TextFormField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              decoration: _deco('correo@ejemplo.com', Icons.person_outline),
              validator: _validarCorreo,
            ),
          ),
          if (_vista != _Vista.olvido) ...[
            const SizedBox(height: 20),
            Campo(
              label: 'Contraseña',
              child: TextFormField(
                controller: _clave,
                obscureText: !_verClave,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _enviar(),
                decoration: _deco(
                  '••••••••',
                  Icons.lock_outline,
                  sufijo: IconButton(
                    icon: Icon(_verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.slate400),
                    onPressed: () => setState(() => _verClave = !_verClave),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Este campo es obligatorio.';
                  if (v.length < 6) return 'Debe tener al menos 6 caracteres.';
                  return null;
                },
              ),
            ),
          ],
          if (_vista == _Vista.login)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _cambiar(_Vista.olvido),
                child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w500)),
              ),
            )
          else
            const SizedBox(height: 16),
          if (_error.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.red50,
                border: Border.all(color: AppColors.red200),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(color: AppColors.red500, shape: BoxShape.circle),
                    child: const Icon(Icons.priority_high, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error, style: const TextStyle(color: AppColors.red700, fontSize: 14))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _BotonLogin(texto: _cargando ? cargandoTxt : boton, cargando: _cargando, onPressed: _enviar),
          const SizedBox(height: 8),
          if (_vista == _Vista.login)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('¿No tienes cuenta?', style: TextStyle(color: AppColors.slate500, fontSize: 14)),
                TextButton(
                  onPressed: () => _cambiar(_Vista.registro),
                  child: const Text('Crear cuenta', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600)),
                ),
              ],
            )
          else
            TextButton(
              onPressed: () => _cambiar(_Vista.login),
              child: const Text('← Volver a iniciar sesión', style: TextStyle(color: AppColors.slate500)),
            ),
        ],
      ),
    );
  }

  Widget _enviado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.green50,
            border: Border.all(color: AppColors.green200),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: AppColors.green600),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Si no lo ves, revisa la carpeta de correo no deseado.',
                  style: TextStyle(color: AppColors.green700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _BotonLogin(texto: 'Volver a iniciar sesión', cargando: false, onPressed: () => _cambiar(_Vista.login)),
      ],
    );
  }
}

/// .login-submit: botón azul alto con flecha
class _BotonLogin extends StatelessWidget {
  const _BotonLogin({required this.texto, required this.cargando, required this.onPressed});

  final String texto;
  final bool cargando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.blue, AppColors.loginDeep]),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [BoxShadow(color: Color(0x402563EB), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: TextButton(
          onPressed: cargando ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (cargando)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                Text(texto),
              const SizedBox(width: 8),
              if (!cargando) const Icon(Icons.arrow_forward, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ondas translúcidas del fondo (.login-bg)
class _OndasFondo extends CustomPainter {
  const _OndasFondo();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final relleno = Paint()..color = Colors.white.withValues(alpha: 0.1);
    final linea = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    Path onda(double y, double amp) => Path()
      ..moveTo(0, y)
      ..cubicTo(w * 0.25, y - amp, w * 0.45, y + amp, w * 0.6, y)
      ..cubicTo(w * 0.75, y - amp, w * 0.9, y + amp * 0.6, w, y - amp * 0.3);

    final arriba = onda(h * 0.28, 60)
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(arriba, relleno);
    canvas.drawPath(onda(h * 0.33, 60), linea);

    final abajo = onda(h * 0.62, 70)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(abajo, Paint()..color = Colors.white.withValues(alpha: 0.12));
    canvas.drawPath(onda(h * 0.68, 70), linea);
    final abajo2 = onda(h * 0.8, 50)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(abajo2, Paint()..color = Colors.white.withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
