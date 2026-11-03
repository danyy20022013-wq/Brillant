import 'package:shelf/shelf.dart';

import 'base_datos.dart';
import 'peticiones.dart';
import 'respuestas.dart';
import 'servicios.dart';
import 'validacion.dart';

/// POST /registro
///
/// Cuerpo: `{"nombre": "...", "correo": "...", "contrasena": "..."}`.
/// - 201 con `{"usuario": {"id", "nombre", "correo"}}`.
/// - 400 si los datos no son válidos (con el mismo mensaje que la app).
/// - 409 si el correo o el nombre ya existen.
Future<Response> rutaRegistro(Request peticion, Servicios servicios) async {
  final Map<String, Object?> datos;
  try {
    datos = await leerJson(peticion);
  } on CuerpoInvalido catch (e) {
    return respuestaError(e.estado, e.mensaje);
  }

  final nombre = campoTexto(datos, 'nombre');
  final correo = campoTexto(datos, 'correo');
  final contrasena = campoTexto(datos, 'contrasena');

  final error = validarNombre(nombre) ??
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
