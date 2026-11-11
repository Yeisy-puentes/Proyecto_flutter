import 'package:firebase_auth/firebase_auth.dart';

/// Todo lo relacionado con cuentas de usuario pasa por esta clase.
/// Las pantallas NO hablan directamente con Firebase: le piden a AuthService.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Avisa cada vez que alguien inicia o cierra sesión.
  Stream<User?> get cambiosDeSesion => _auth.authStateChanges();

  /// Usuario con sesión abierta (null si no hay nadie).
  User? get usuarioActual => _auth.currentUser;

  Future<void> iniciarSesion(String correo, String clave) async {
    await _auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: clave,
    );
  }

  Future<void> registrar(String nombre, String correo, String clave) async {
    final credencial = await _auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: clave,
    );
    await credencial.user?.updateDisplayName(nombre.trim());
  }

  Future<void> recuperarClave(String correo) {
    return _auth.sendPasswordResetEmail(email: correo.trim());
  }

  Future<void> cerrarSesion() {
    return _auth.signOut();
  }

  /// Traduce los códigos de error de Firebase a mensajes en español.
  static String mensajeDeError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento y vuelve a intentar.';
      case 'network-request-failed':
        return 'No hay conexión a internet.';
      case 'operation-not-allowed':
        return 'Activa "Correo electrónico/contraseña" en Firebase Authentication.';
      default:
        return 'Error de Firebase: ${e.code}';
    }
  }
}
