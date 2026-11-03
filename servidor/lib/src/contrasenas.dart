import 'dart:convert';
import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';

import 'validacion.dart';

/// Hash y verificación de contraseñas con bcrypt.
///
/// El cálculo corre en otro isolate para no frenar las demás peticiones
/// mientras dura (cientos de milisegundos con el costo de producción).
class Contrasenas {
  /// Costo de bcrypt (log2 de las rondas). Cada +1 duplica el tiempo.
  final int costo;

  const Contrasenas({required this.costo});

  /// Hash bcrypt de [contrasena]. La sal sale de Random.secure().
  Future<String> hashear(String contrasena) {
    _comprobarLargo(contrasena);
    final costo = this.costo;
    return Isolate.run(
      () => BCrypt.hashpw(contrasena, BCrypt.gensalt(logRounds: costo)),
    );
  }

  /// true si [contrasena] corresponde a [hash]. Un hash dañado o una
  /// contraseña demasiado larga dan false (nunca lanzan).
  Future<bool> verificar(String contrasena, String hash) async {
    if (utf8.encode(contrasena).length > maximoBytesContrasena) return false;
    try {
      return await Isolate.run(() => BCrypt.checkpw(contrasena, hash));
    } catch (_) {
      return false;
    }
  }

  static void _comprobarLargo(String contrasena) {
    if (utf8.encode(contrasena).length > maximoBytesContrasena) {
      throw ArgumentError('La contraseña supera $maximoBytesContrasena bytes');
    }
  }
}
