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

/// La sesión ya no vale (token inválido, vencido o cuenta borrada): la app
/// debe olvidar el token y volver al inicio de sesión.
class SesionVencidaException extends AuthException {
  const SesionVencidaException([
    super.mensaje = 'Tu sesión venció. Vuelve a iniciar sesión.',
  ]);
}

/// No se pudo hablar con el servidor (sin conexión o tiempo agotado).
class ServidorNoDisponibleException extends AuthException {
  const ServidorNoDisponibleException(super.mensaje);
}

/// Acceso a las cuentas. La app usa el servidor (ApiAuthRepository); las
/// pruebas, la versión en memoria.
abstract class AuthRepository {
  /// Crea la cuenta y deja la sesión iniciada.
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
  });

  Future<Usuario> iniciarSesion({
    required String correo,
    required String contrasena,
  });

  /// Usuario de la sesión guardada, o null si no hay una válida (en ese caso
  /// la sesión guardada se olvida).
  Future<Usuario?> restaurarSesion();

  Future<void> cerrarSesion();

  /// Borra la cuenta de la sesión actual pidiendo otra vez la contraseña.
  /// Si sale bien, también cierra la sesión. Lanza [AuthException] si la
  /// contraseña no es correcta y [SesionVencidaException] si la sesión ya no
  /// vale.
  Future<void> borrarCuenta(String contrasena);
}

class _Cuenta {
  final Usuario usuario;
  final String contrasena;

  const _Cuenta(this.usuario, this.contrasena);
}

/// Cuentas guardadas solo mientras la app está abierta. Solo para pruebas.
class InMemoryAuthRepository implements AuthRepository {
  final Duration retraso;
  final Map<String, _Cuenta> _cuentas = {};

  /// Correo de la sesión iniciada (null si no hay sesión).
  String? _sesion;

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
    _sesion = clave;
    return usuario;
  }

  @override
  Future<Usuario> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    await _esperar();
    final clave = correo.trim().toLowerCase();
    final cuenta = _cuentas[clave];
    if (cuenta == null || cuenta.contrasena != contrasena) {
      throw const AuthException('Correo o contraseña incorrectos');
    }
    _sesion = clave;
    return cuenta.usuario;
  }

  @override
  Future<Usuario?> restaurarSesion() async {
    await _esperar();
    final cuenta = _cuentas[_sesion];
    if (cuenta == null) _sesion = null;
    return cuenta?.usuario;
  }

  @override
  Future<void> cerrarSesion() async {
    _sesion = null;
  }

  @override
  Future<void> borrarCuenta(String contrasena) async {
    await _esperar();
    final cuenta = _cuentas[_sesion];
    if (cuenta == null) {
      _sesion = null;
      throw const SesionVencidaException();
    }
    if (cuenta.contrasena != contrasena) {
      throw const AuthException('La contraseña no es correcta');
    }
    _cuentas.remove(_sesion);
    _sesion = null;
  }
}
