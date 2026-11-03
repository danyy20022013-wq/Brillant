import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Imprime una clave al azar para JWT_SECRETO (48 bytes de Random.secure en
/// base64url, unos 64 caracteres). Cópiala en tu archivo .env; no la subas a
/// git ni la compartas.
void main() {
  final random = Random.secure();
  final bytes = List<int>.generate(48, (_) => random.nextInt(256));
  stdout.writeln(base64Url.encode(bytes).replaceAll('=', ''));
}
