import 'package:equatable/equatable.dart';

class Usuario extends Equatable {
  final String nombre;
  final String correo;

  const Usuario({required this.nombre, required this.correo});

  @override
  List<Object?> get props => [nombre, correo];
}

/// Error que se le puede mostrar al jugador (correo repetido, clave mala...).
class AuthException implements Exception {
  final String mensaje;

  const AuthException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Acceso a las cuentas. Hoy es en memoria; más adelante se reemplaza por
/// un servidor (Firebase, API propia...) sin cambiar las pantallas.
abstract class AuthRepository {
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
  });

  Future<Usuario> iniciarSesion({
    required String correo,
    required String contrasena,
  });

  Future<void> cerrarSesion();
}

class _Cuenta {
  final Usuario usuario;
  final String contrasena;

  const _Cuenta(this.usuario, this.contrasena);
}

/// Cuentas guardadas solo mientras la app está abierta.
/// Es para desarrollo: un servidor real debe guardar la contraseña cifrada.
class InMemoryAuthRepository implements AuthRepository {
  final Duration retraso;
  final Map<String, _Cuenta> _cuentas = {};

  InMemoryAuthRepository({this.retraso = const Duration(milliseconds: 400)});

  Future<void> _esperar() async {
    if (retraso > Duration.zero) await Future<void>.delayed(retraso);
  }

  @override
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    await _esperar();
    final clave = correo.trim().toLowerCase();
    final nombreLimpio = nombre.trim();

    if (_cuentas.containsKey(clave)) {
      throw const AuthException('Ese correo ya está registrado');
    }
    final nombreOcupado = _cuentas.values.any(
      (c) => c.usuario.nombre.toLowerCase() == nombreLimpio.toLowerCase(),
    );
    if (nombreOcupado) {
      throw const AuthException('Ese nombre de usuario ya está en uso');
    }

    final usuario = Usuario(nombre: nombreLimpio, correo: clave);
    _cuentas[clave] = _Cuenta(usuario, contrasena);
    return usuario;
  }

  @override
  Future<Usuario> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    await _esperar();
    final cuenta = _cuentas[correo.trim().toLowerCase()];
    if (cuenta == null || cuenta.contrasena != contrasena) {
      throw const AuthException('Correo o contraseña incorrectos');
    }
    return cuenta.usuario;
  }

  @override
  Future<void> cerrarSesion() async {}
}