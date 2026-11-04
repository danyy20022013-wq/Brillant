import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dónde se guarda el token de la sesión entre una apertura y otra.
abstract class AlmacenSesion {
  /// El token guardado, o null si no hay.
  Future<String?> leerToken();

  Future<void> guardarToken(String token);

  Future<void> borrarToken();
}

/// Guarda el token solo mientras la app está abierta. Para las pruebas.
class AlmacenSesionEnMemoria implements AlmacenSesion {
  String? _token;

  AlmacenSesionEnMemoria([this._token]);

  @override
  Future<String?> leerToken() async => _token;

  @override
  Future<void> guardarToken(String token) async => _token = token;

  @override
  Future<void> borrarToken() async => _token = null;
}

/// Guarda el token con flutter_secure_storage.
///
/// En la web es experimental (lo dice el propio paquete): usa WebCrypto y
/// LocalStorage, y solo funciona en HTTPS o en localhost. Si falla, la app
/// sigue funcionando: simplemente no queda la sesión guardada y al volver a
/// abrir hay que iniciar sesión otra vez. Nunca se registra el token.
class AlmacenSesionSegura implements AlmacenSesion {
  static const _clave = 'brilliant_token';

  final FlutterSecureStorage _almacen;

  AlmacenSesionSegura([FlutterSecureStorage? almacen])
    : _almacen = almacen ?? const FlutterSecureStorage();

  @override
  Future<String?> leerToken() async {
    try {
      final token = await _almacen.read(key: _clave);
      return (token == null || token.isEmpty) ? null : token;
    } catch (e) {
      _avisar('leer', e);
      return null;
    }
  }

  @override
  Future<void> guardarToken(String token) async {
    try {
      await _almacen.write(key: _clave, value: token);
    } catch (e) {
      _avisar('guardar', e);
    }
  }

  @override
  Future<void> borrarToken() async {
    try {
      await _almacen.delete(key: _clave);
    } catch (e) {
      _avisar('borrar', e);
    }
  }

  /// Solo el tipo de error: nunca el token.
  static void _avisar(String accion, Object error) {
    debugPrint('No se pudo $accion la sesión guardada (${error.runtimeType}).');
  }
}
