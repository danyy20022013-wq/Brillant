import 'dart:convert';

import 'package:shelf/shelf.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

/// Respuesta JSON con [cuerpo].
Response respuestaJson(
  int estado,
  Object cuerpo, {
  Map<String, String> cabeceras = const {},
}) => Response(
  estado,
  body: jsonEncode(cuerpo),
  headers: {..._json, ...cabeceras},
);

/// Error con un mensaje en español pensado para mostrarse al jugador.
/// Nunca lleva detalles internos.
Response respuestaError(
  int estado,
  String mensaje, {
  Map<String, String> cabeceras = const {},
}) => respuestaJson(estado, {'error': mensaje}, cabeceras: cabeceras);

/// Atrapa cualquier error inesperado: responde 500 con un mensaje genérico y
/// registra solo el tipo de error (nunca datos de la petición).
Middleware manejarErrores({void Function(String)? registrar}) {
  final log = registrar ?? (_) {};
  return (Handler interno) {
    return (Request peticion) async {
      try {
        return await interno(peticion);
      } on HijackException {
        rethrow;
      } catch (e) {
        log(
          'Error interno (${e.runtimeType}) en '
          '${peticion.method} /${peticion.url.path}',
        );
        return respuestaError(500, 'Error interno del servidor');
      }
    };
  };
}

/// Registra método, ruta, estado y tiempo. No registra cabeceras, cuerpo ni
/// parámetros, así que nunca escribe contraseñas ni tokens.
Middleware registrarPeticiones(void Function(String) registrar) {
  return (Handler interno) {
    return (Request peticion) async {
      final inicio = DateTime.now();
      final respuesta = await interno(peticion);
      final ms = DateTime.now().difference(inicio).inMilliseconds;
      registrar(
        '${peticion.method} /${peticion.url.path} '
        '${respuesta.statusCode} ${ms}ms',
      );
      return respuesta;
    };
  };
}
