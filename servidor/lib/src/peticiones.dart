import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Tamaño máximo del cuerpo de una petición (las nuestras son pequeñas).
const maximoBytesCuerpo = 16 * 1024;

/// El cuerpo no es un objeto JSON válido o es demasiado grande.
class CuerpoInvalido implements Exception {
  /// 400 si no es JSON válido; 413 si es demasiado grande.
  final int estado;
  final String mensaje;

  const CuerpoInvalido(this.estado, this.mensaje);
}

/// Lee el cuerpo como un objeto JSON. Lanza [CuerpoInvalido].
Future<Map<String, Object?>> leerJson(Request peticion) async {
  final largo = peticion.contentLength;
  if (largo != null && largo > maximoBytesCuerpo) {
    throw const CuerpoInvalido(413, 'La petición es demasiado grande');
  }

  final bytes = <int>[];
  await for (final trozo in peticion.read()) {
    bytes.addAll(trozo);
    if (bytes.length > maximoBytesCuerpo) {
      throw const CuerpoInvalido(413, 'La petición es demasiado grande');
    }
  }

  try {
    final datos = jsonDecode(utf8.decode(bytes));
    if (datos is Map<String, Object?>) return datos;
  } on FormatException {
    // cae al error de abajo
  }
  throw const CuerpoInvalido(400, 'Datos inválidos');
}

/// Campo de texto de [datos], o null si falta o no es texto.
String? campoTexto(Map<String, Object?> datos, String clave) {
  final valor = datos[clave];
  return valor is String ? valor : null;
}
