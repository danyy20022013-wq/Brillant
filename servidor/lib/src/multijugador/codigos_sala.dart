import 'dart:math';

/// Letras y números de los códigos de sala. Sin 0, O, 1, I ni L, que se
/// confunden al dictarlos o leerlos.
const alfabetoCodigoSala = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Largo del código de sala.
const largoCodigoSala = 6;

/// Código de sala al azar. [random] debe ser seguro (Random.secure) fuera
/// de las pruebas.
String generarCodigoSala(Random random) => String.fromCharCodes(
  List.generate(
    largoCodigoSala,
    (_) => alfabetoCodigoSala.codeUnitAt(
      random.nextInt(alfabetoCodigoSala.length),
    ),
  ),
);

/// Pasa a mayúsculas y quita espacios. Devuelve null si no tiene la forma
/// de un código (largo o caracteres no permitidos).
String? normalizarCodigoSala(Object? codigo) {
  if (codigo is! String) return null;
  final limpio = codigo.trim().toUpperCase();
  if (limpio.length != largoCodigoSala) return null;
  for (final c in limpio.split('')) {
    if (!alfabetoCodigoSala.contains(c)) return null;
  }
  return limpio;
}
