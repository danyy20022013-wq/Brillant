import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'auth_repository.dart';

sealed class AuthEstado extends Equatable {
  const AuthEstado();

  @override
  List<Object?> get props => [];
}

/// Al abrir la app: se está comprobando si hay una sesión guardada.
class AuthComprobando extends AuthEstado {
  const AuthComprobando();
}

/// Nadie ha iniciado sesión. [cargando] indica que se está enviando el
/// formulario; [error], el mensaje a mostrar.
class AuthSinSesion extends AuthEstado {
  final bool cargando;
  final String? error;

  const AuthSinSesion({this.cargando = false, this.error});

  @override
  List<Object?> get props => [cargando, error];
}

class AuthConSesion extends AuthEstado {
  final Usuario usuario;

  const AuthConSesion(this.usuario);

  @override
  List<Object?> get props => [usuario];
}

class AuthCubit extends Cubit<AuthEstado> {
  final AuthRepository _repositorio;

  AuthCubit(this._repositorio) : super(const AuthComprobando());

  bool get _cargando =>
      state is AuthSinSesion && (state as AuthSinSesion).cargando;

  /// Al abrir la app: restaura la sesión guardada si sigue valiendo. Si el
  /// token venció (401), el repositorio lo borra y se vuelve al login. Si el
  /// servidor no responde, se va al login con el mensaje del error.
  Future<void> iniciar() async {
    if (state is! AuthComprobando) return;
    try {
      final usuario = await _repositorio.restaurarSesion();
      emit(usuario == null ? const AuthSinSesion() : AuthConSesion(usuario));
    } on AuthException catch (e) {
      emit(AuthSinSesion(error: e.mensaje));
    }
  }

  Future<void> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    if (_cargando) return;
    emit(const AuthSinSesion(cargando: true));
    try {
      final usuario = await _repositorio.iniciarSesion(
        correo: correo,
        contrasena: contrasena,
      );
      emit(AuthConSesion(usuario));
    } on AuthException catch (e) {
      emit(AuthSinSesion(error: e.mensaje));
    }
  }

  Future<void> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    if (_cargando) return;
    emit(const AuthSinSesion(cargando: true));
    try {
      final usuario = await _repositorio.registrar(
        nombre: nombre,
        correo: correo,
        contrasena: contrasena,
      );
      emit(AuthConSesion(usuario));
    } on AuthException catch (e) {
      emit(AuthSinSesion(error: e.mensaje));
    }
  }

  Future<void> cerrarSesion() async {
    await _repositorio.cerrarSesion();
    emit(const AuthSinSesion());
  }

  /// Borra la cuenta de la sesión actual. Devuelve null si terminó la sesión
  /// (cuenta borrada, o sesión vencida: en ese caso el login muestra el
  /// aviso) y el mensaje de error si la sesión sigue (contraseña incorrecta,
  /// demasiados intentos, sin conexión...).
  Future<String?> borrarCuenta(String contrasena) async {
    if (state is! AuthConSesion) return null;
    try {
      await _repositorio.borrarCuenta(contrasena);
      emit(const AuthSinSesion());
      return null;
    } on SesionVencidaException catch (e) {
      emit(AuthSinSesion(error: e.mensaje));
      return null;
    } on AuthException catch (e) {
      // Incluye el 403 de contraseña incorrecta: la sesión NO se cierra.
      return e.mensaje;
    }
  }

  /// Quita el mensaje de error al cambiar de pantalla.
  void limpiarError() {
    final actual = state;
    if (actual is AuthSinSesion && actual.error != null) {
      emit(const AuthSinSesion());
    }
  }
}
