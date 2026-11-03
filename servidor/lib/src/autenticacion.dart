import 'dart:io';

import 'package:shelf/shelf.dart';

import 'base_datos.dart';
import 'respuestas.dart';
import 'servicios.dart';
import 'tokens.dart';

/// Mensaje único para cualquier problema con el token.
const mensajeSesionInvalida = 'Tu sesión no es válida o ya venció';

/// 401 con WWW-Authenticate, igual para todos los problemas de token.
Response respuestaSesionInvalida() => respuestaError(
  401,
  mensajeSesionInvalida,
  cabeceras: {'www-authenticate': 'Bearer'},
);

/// Usuario dueño del token de `Authorization: Bearer ...`, o null si falta,
/// no es válido, venció o la cuenta ya no existe.
UsuarioGuardado? usuarioDelToken(Request peticion, Servicios servicios) {
  final cabecera = peticion.headers['authorization'];
  if (cabecera == null) return null;
  const prefijo = 'bearer ';
  if (cabecera.length <= prefijo.length ||
      cabecera.substring(0, prefijo.length).toLowerCase() != prefijo) {
    return null;
  }
  try {
    final id = servicios.tokens.verificar(
      cabecera.substring(prefijo.length).trim(),
    );
    // La cuenta puede haberse borrado después de emitir el token.
    return servicios.usuarios.porId(id);
  } on TokenInvalido {
    return null;
  }
}

/// IP de quien hace la petición (la de la conexión). Detrás de un proxy
/// inverso habría que leer X-Forwarded-For solo si se confía en el proxy.
String ipDe(Request peticion) {
  final conexion = peticion.context['shelf.io.connection_info'];
  if (conexion is HttpConnectionInfo) return conexion.remoteAddress.address;
  return 'desconocida';
}
