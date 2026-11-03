import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';

import 'validacion.dart';

/// Hash y verificación de contraseñas con bcrypt.
///
/// El cálculo corre en otro isolate para no frenar las demás peticiones
/// mientras dura (cientos de milisegundos con el costo de producción).
class Contrasenas {
  /// Costo de bcrypt (log2 de las rondas). Cada +1 duplica el tiempo.
  final int costo;

  Contrasenas({required this.costo});

  /// Hash de una contraseña al azar, con el mismo costo. El inicio de
  /// sesión lo compara cuando el correo no existe, para tardar lo mismo
  /// que con un correo real y no revelar cuáles existen.
  late final Future<String> hashDeRelleno = hashear(
    List.generate(24, (_) => _random.nextInt(36).toRadixString(36)).join(),
  );

  static final _random = Random.secure();

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
