import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'auth_repository.dart';

sealed class AuthEstado extends Equatable {
  const AuthEstado();

  @override
  List<Object?> get props => [];
}

/// Nadie ha iniciado sesión (o se está comprobando).
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

  AuthCubit(this._repositorio) : super(const AuthSinSesion());

  bool get _cargando =>
      state is AuthSinSesion && (state as AuthSinSesion).cargando;

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

  /// Quita el mensaje de error al cambiar de pantalla.
  void limpiarError() {
    final actual = state;
    if (actual is AuthSinSesion && actual.error != null) {
      emit(const AuthSinSesion());
    }
  }
}