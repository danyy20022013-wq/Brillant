import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'almacen_sesion.dart';
import 'auth_repository.dart';

/// Dirección del servidor. Se cambia al compilar o ejecutar con
/// `--dart-define=API_URL=https://...`. Por defecto, el servidor local en el
/// puerto que usa el servidor por defecto (8080).
const urlServidorPorDefecto = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080',
);

/// Mensajes que ve el jugador cuando algo falla fuera de su control.
abstract final class MensajesServidor {
  static const sinConexion =
      'No se pudo conectar con el servidor. Revisa tu conexión o inténtalo '
      'más tarde.';
  static const tiempoAgotado =
      'El servidor tardó demasiado en responder. Inténtalo de nuevo.';
  static const datosInvalidos = 'Los datos no son válidos. Revísalos.';
  static const demasiadoGrande = 'Los datos enviados son demasiado grandes.';
  static const errorServidor =
      'El servidor tuvo un problema. Inténtalo más tarde.';
  static const respuestaRara = 'El servidor respondió algo inesperado.';
  static const contrasenaIncorrecta = 'La contraseña no es correcta';

  /// Mensaje para un 429 según la cabecera Retry-After (en segundos).
  static String esperar(int? segundos) {
    if (segundos == null || segundos <= 0) {
      return 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
    }
    final unidad = segundos == 1 ? 'segundo' : 'segundos';
    return 'Demasiados intentos. Espera $segundos $unidad e inténtalo de '
        'nuevo.';
  }
}

/// Cuentas en el servidor de Brilliant (carpeta servidor/ del repositorio).
///
/// Contrato del servidor:
/// - POST /registro → 201 sin token; después se llama a POST /sesion.
/// - POST /sesion → 200 con `token`.
/// - GET /cuenta → 200 con el usuario (restaura la sesión).
/// - DELETE /cuenta → 204; 403 si la contraseña no es correcta.
/// - 401 en GET o DELETE /cuenta: token inválido o vencido.
/// - 429 trae Retry-After en segundos.
class ApiAuthRepository implements AuthRepository {
  final Uri _base;
  final http.Client _cliente;
  final Duration tiempoLimite;

  /// Dónde se guarda el token entre una apertura y otra.
  final AlmacenSesion _almacen;

  /// Token de la sesión actual. Se guarda también en [_almacen]; si guardar
  /// falla (por ejemplo en la web), la sesión sigue funcionando hasta cerrar
  /// la app.
  String? _token;

  ApiAuthRepository({
    String urlBase = urlServidorPorDefecto,
    http.Client? cliente,
    AlmacenSesion? almacen,
    this.tiempoLimite = const Duration(seconds: 10),
  }) : _base = Uri.parse(urlBase.endsWith('/') ? urlBase : '$urlBase/'),
       _cliente = cliente ?? http.Client(),
       _almacen = almacen ?? AlmacenSesionEnMemoria();

  /// Hay un token en esta sesión.
  bool get tieneToken => _token != null;

  Future<void> _guardarToken(String token) async {
    _token = token;
    await _almacen.guardarToken(token);
  }

  Future<void> _olvidarToken() async {
    _token = null;
    await _almacen.borrarToken();
  }

  @override
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    final respuesta = await _enviar(
      'POST',
      'registro',
      cuerpo: {'nombre': nombre, 'correo': correo, 'contrasena': contrasena},
    );
    if (respuesta.statusCode != 201) throw _error(respuesta);
    // El registro no entrega token: se inicia sesión con los mismos datos.
    return iniciarSesion(correo: correo, contrasena: contrasena);
  }

  @override
  Future<Usuario> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final respuesta = await _enviar(
      'POST',
      'sesion',
      cuerpo: {'correo': correo, 'contrasena': contrasena},
    );
    if (respuesta.statusCode != 200) throw _error(respuesta);

    final datos = _json(respuesta);
    final token = datos['token'];
    if (token is! String || token.isEmpty) {
      throw const AuthException(MensajesServidor.respuestaRara);
    }
    final usuario = _usuario(datos);
    await _guardarToken(token);
    return usuario;
  }

  @override
  Future<Usuario?> restaurarSesion() async {
    final token = _token ??= await _almacen.leerToken();
    if (token == null) return null;

    final respuesta = await _enviar('GET', 'cuenta', token: token);
    if (respuesta.statusCode == 401) {
      // Token inválido o vencido: se olvida y hay que iniciar sesión.
      await _olvidarToken();
      return null;
    }
    if (respuesta.statusCode != 200) throw _error(respuesta);
    return _usuario(_json(respuesta));
  }

  @override
  Future<void> cerrarSesion() async {
    // Los tokens no se guardan en el servidor: basta con olvidarlo.
    await _olvidarToken();
  }

  @override
  Future<void> borrarCuenta(String contrasena) async {
    final token = _token ??= await _almacen.leerToken();
    if (token == null) throw const SesionVencidaException();

    final respuesta = await _enviar(
      'DELETE',
      'cuenta',
      token: token,
      cuerpo: {'contrasena': contrasena},
    );
    switch (respuesta.statusCode) {
      case 204:
        await _olvidarToken();
      case 401:
        await _olvidarToken();
        throw const SesionVencidaException();
      case 403:
        // La contraseña no es correcta: la sesión sigue valiendo.
        throw AuthException(
          _mensajeDelServidor(respuesta) ??
              MensajesServidor.contrasenaIncorrecta,
        );
      default:
        throw _error(respuesta);
    }
  }

  // ───────────── HTTP ─────────────

  Future<http.Response> _enviar(
    String metodo,
    String ruta, {
    String? token,
    Map<String, Object?>? cuerpo,
  }) async {
    final peticion = http.Request(metodo, _base.resolve(ruta))
      ..headers.addAll({
        'accept': 'application/json',
        if (cuerpo != null) 'content-type': 'application/json; charset=utf-8',
        if (token != null) 'authorization': 'Bearer $token',
      });
    if (cuerpo != null) peticion.body = jsonEncode(cuerpo);

    try {
      final enviada = await _cliente.send(peticion).timeout(tiempoLimite);
      return await http.Response.fromStream(enviada).timeout(tiempoLimite);
    } on TimeoutException {
      throw const ServidorNoDisponibleException(MensajesServidor.tiempoAgotado);
    } on http.ClientException {
      throw const ServidorNoDisponibleException(MensajesServidor.sinConexion);
    }
  }

  /// Error para el jugador según el código de la respuesta.
  AuthException _error(http.Response respuesta) {
    final mensaje = _mensajeDelServidor(respuesta);
    return switch (respuesta.statusCode) {
      400 => AuthException(mensaje ?? MensajesServidor.datosInvalidos),
      401 => AuthException(mensaje ?? 'Correo o contraseña incorrectos'),
      403 => AuthException(mensaje ?? MensajesServidor.contrasenaIncorrecta),
      409 => AuthException(mensaje ?? MensajesServidor.datosInvalidos),
      413 => const AuthException(MensajesServidor.demasiadoGrande),
      429 => AuthException(
        MensajesServidor.esperar(
          int.tryParse(respuesta.headers['retry-after'] ?? ''),
        ),
      ),
      >= 500 => const AuthException(MensajesServidor.errorServidor),
      _ => const AuthException(MensajesServidor.respuestaRara),
    };
  }

  /// El campo "error" del cuerpo, si viene.
  static String? _mensajeDelServidor(http.Response respuesta) {
    try {
      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (datos is Map && datos['error'] is String) {
        return datos['error'] as String;
      }
    } on FormatException {
      // sin cuerpo JSON
    }
    return null;
  }

  static Map<String, Object?> _json(http.Response respuesta) {
    try {
      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (datos is Map<String, Object?>) return datos;
    } on FormatException {
      // cae al error de abajo
    }
    throw const AuthException(MensajesServidor.respuestaRara);
  }

  static Usuario _usuario(Map<String, Object?> datos) {
    final usuario = datos['usuario'];
    if (usuario is Map &&
        usuario['nombre'] is String &&
        usuario['correo'] is String) {
      return Usuario(
        nombre: usuario['nombre'] as String,
        correo: usuario['correo'] as String,
      );
    }
    throw const AuthException(MensajesServidor.respuestaRara);
  }
}
