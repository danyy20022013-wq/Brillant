import 'package:shelf/shelf.dart';

import 'autenticacion.dart';
import 'base_datos.dart';
import 'limitador.dart';
import 'peticiones.dart';
import 'respuestas.dart';
import 'servicios.dart';
import 'validacion.dart';

/// Mensaje único para un inicio de sesión fallido, exista o no el correo.
const mensajeCredencialesIncorrectas = 'Correo o contraseña incorrectos';

/// 429 con Retry-After y un mensaje en minutos.
Response demasiadosIntentos(Duration falta) {
  final minutos = (falta.inSeconds / 60).ceil();
  return respuestaError(
    429,
    'Demasiados intentos. Prueba de nuevo en '
    '${minutos <= 1 ? '1 minuto' : '$minutos minutos'}.',
    cabeceras: {'retry-after': segundosParaReintentar(falta)},
  );
}

/// POST /registro
///
/// Cuerpo: `{"nombre": "...", "correo": "...", "contrasena": "..."}`.
/// - 201 con `{"usuario": {"id", "nombre", "correo"}}`.
/// - 400 si los datos no son válidos (con el mismo mensaje que la app).
/// - 409 si el correo o el nombre ya existen.
/// - 429 si esa IP ya hizo demasiados intentos de registro.
///
/// No entrega token: la app inicia sesión después con POST /sesion.
Future<Response> rutaRegistro(Request peticion, Servicios servicios) async {
  final claveIp = 'registro-ip:${ipDe(peticion)}';
  final limitador = servicios.intentosRegistro;
  final falta = limitador.bloqueo(claveIp);
  if (falta != null) return demasiadosIntentos(falta);
  limitador.registrar(claveIp);

  final Map<String, Object?> datos;
  try {
    datos = await leerJson(peticion);
  } on CuerpoInvalido catch (e) {
    return respuestaError(e.estado, e.mensaje);
  }

  final nombre = campoTexto(datos, 'nombre');
  final correo = campoTexto(datos, 'correo');
  final contrasena = campoTexto(datos, 'contrasena');

  final error =
      validarNombre(nombre) ??
      validarCorreo(correo) ??
      validarContrasena(contrasena);
  if (error != null) return respuestaError(400, error);

  final usuarios = servicios.usuarios;
  if (usuarios.porCorreo(correo!) != null) {
    return respuestaError(409, 'Ese correo ya está registrado');
  }
  if (usuarios.existeNombre(nombre!)) {
    return respuestaError(409, 'Ese nombre de usuario ya está en uso');
  }

  final hash = await servicios.contrasenas.hashear(contrasena!);

  // Mientras se calculaba el hash pudo llegar otro registro con los mismos
  // datos: crear() vuelve a comprobarlo.
  try {
    final usuario = usuarios.crear(
      nombre: nombre,
      correo: correo,
      hash: hash,
      creadoEn: servicios.reloj(),
    );
    return respuestaJson(201, {'usuario': usuario.aJsonPublico()});
  } on CorreoDuplicado {
    return respuestaError(409, 'Ese correo ya está registrado');
  } on NombreDuplicado {
    return respuestaError(409, 'Ese nombre de usuario ya está en uso');
  }
}

/// POST /sesion
///
/// Cuerpo: `{"correo": "...", "contrasena": "..."}`.
/// - 200 con `{"token", "expiraEn", "usuario"}`.
/// - 401 con el mismo mensaje, cabeceras y tiempo aproximado tanto si el
///   correo no existe como si la contraseña es incorrecta.
/// - 429 tras 5 fallos en 15 minutos del mismo correo o de la misma IP.
Future<Response> rutaSesion(Request peticion, Servicios servicios) async {
  final Map<String, Object?> datos;
  try {
    datos = await leerJson(peticion);
  } on CuerpoInvalido catch (e) {
    return respuestaError(e.estado, e.mensaje);
  }
  final correo = campoTexto(datos, 'correo');
  final contrasena = campoTexto(datos, 'contrasena');
  if (correo == null || contrasena == null) {
    return respuestaError(400, 'Datos inválidos');
  }

  final limitador = servicios.intentosSesion;
  final claveCorreo =
      'sesion-correo:${RepositorioUsuarios.normalizarCorreo(correo)}';
  final claveIp = 'sesion-ip:${ipDe(peticion)}';
  final faltas = [
    limitador.bloqueo(claveCorreo),
    limitador.bloqueo(claveIp),
  ].whereType<Duration>().toList();
  if (faltas.isNotEmpty) {
    return demasiadosIntentos(faltas.reduce((a, b) => a > b ? a : b));
  }

  // Si el correo no existe se compara igual contra un hash de relleno, para
  // que la respuesta tarde lo mismo.
  final usuario = servicios.usuarios.porCorreo(correo);
  final hash = usuario?.hash ?? await servicios.contrasenas.hashDeRelleno;
  final coincide = await servicios.contrasenas.verificar(contrasena, hash);

  if (usuario == null || !coincide) {
    limitador
      ..registrar(claveCorreo)
      ..registrar(claveIp);
    return respuestaError(401, mensajeCredencialesIncorrectas);
  }

  limitador.reiniciar(claveCorreo);
  final emitido = servicios.tokens.emitir(usuario.id);
  return respuestaJson(200, {
    'token': emitido.token,
    'expiraEn': emitido.expiraEn.toIso8601String(),
    'usuario': usuario.aJsonPublico(),
  });
}

/// GET /cuenta (con `Authorization: Bearer <token>`)
///
/// - 200 con `{"usuario"}`: sirve para que la app restaure la sesión.
/// - 401 si el token falta, no es válido, venció o la cuenta se borró.
Response rutaCuenta(Request peticion, Servicios servicios) {
  final usuario = usuarioDelToken(peticion, servicios);
  if (usuario == null) return respuestaSesionInvalida();
  return respuestaJson(200, {'usuario': usuario.aJsonPublico()});
}

/// DELETE /cuenta (con `Authorization: Bearer <token>`)
///
/// Cuerpo: `{"contrasena": "..."}`: se pide otra vez la contraseña para que
/// un token robado no baste para borrar la cuenta.
/// - 204 sin cuerpo: la cuenta se borró y sus tokens dejan de servir.
/// - 401 si el token falta, no es válido o venció.
/// - 403 si la contraseña no es la de la cuenta del token.
/// - 429 tras 5 contraseñas incorrectas en 15 minutos para esa cuenta.
Future<Response> rutaBorrarCuenta(Request peticion, Servicios servicios) async {
  final usuario = usuarioDelToken(peticion, servicios);
  if (usuario == null) return respuestaSesionInvalida();

  final limitador = servicios.intentosSesion;
  final clave = 'borrar-cuenta:${usuario.id}';
  final falta = limitador.bloqueo(clave);
  if (falta != null) return demasiadosIntentos(falta);

  final Map<String, Object?> datos;
  try {
    datos = await leerJson(peticion);
  } on CuerpoInvalido catch (e) {
    return respuestaError(e.estado, e.mensaje);
  }
  final contrasena = campoTexto(datos, 'contrasena');
  if (contrasena == null) return respuestaError(400, 'Datos inválidos');

  final coincide = await servicios.contrasenas.verificar(
    contrasena,
    usuario.hash,
  );
  if (!coincide) {
    limitador.registrar(clave);
    return respuestaError(403, 'La contraseña no es correcta');
  }

  servicios.usuarios.borrar(usuario.id);
  limitador.reiniciar(clave);
  return Response(204);
}
