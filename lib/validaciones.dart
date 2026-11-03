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
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)) {
    return 'Correo no válido';
  }
  return null;
}

String? validarContrasena(String? valor) {
  final texto = valor ?? '';
  if (texto.isEmpty) return 'Escribe tu contraseña';
  if (texto.length < 6) return 'Mínimo 6 caracteres';
  return null;
}

String? validarConfirmacion(String? valor, String contrasena) {
  if ((valor ?? '').isEmpty) return 'Repite tu contraseña';
  if (valor != contrasena) return 'Las contraseñas no coinciden';
  return null;
}