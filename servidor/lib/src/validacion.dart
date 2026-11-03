import 'dart:convert';

// Las mismas reglas y mensajes que lib/validaciones.dart de la app: el
// servidor no confía en lo que valida el cliente.

/// Bytes máximos de una contraseña en UTF-8 (bcrypt solo usa 72).
const maximoBytesContrasena = 72;

String? validarNombre(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Escribe tu nombre de usuario';
  if (texto.length < 3) return 'Mínimo 3 caracteres';
  if (texto.length > 16) return 'Máximo 16 caracteres';
  if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(texto)) {
    return 'Solo letras, números y _';
  }
  return null;
}

String? validarCorreo(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Escribe tu correo';
  if (texto.length > 254) return 'Correo no válido';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)) {
    return 'Correo no válido';
  }
  return null;
}

String? validarContrasena(String? valor) {
  final texto = valor ?? '';
  if (texto.isEmpty) return 'Escribe tu contraseña';
  if (texto.length < 6) return 'Mínimo 6 caracteres';
  if (utf8.encode(texto).length > maximoBytesContrasena) {
    return 'Máximo 72 bytes (las tildes y la ñ ocupan 2)';
  }
  return null;
}
