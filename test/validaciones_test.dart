import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/validaciones.dart';

void main() {
  group('validarNombre', () {
    test('acepta nombres válidos', () {
      for (final nombre in ['dany', 'Dany_20', 'abc', 'a' * 16]) {
        expect(validarNombre(nombre), isNull, reason: nombre);
      }
    });

    test('rechaza vacío, corto, largo y con símbolos', () {
      expect(validarNombre(null), 'Escribe tu nombre de usuario');
      expect(validarNombre('   '), 'Escribe tu nombre de usuario');
      expect(validarNombre('ab'), 'Mínimo 3 caracteres');
      expect(validarNombre('a' * 17), 'Máximo 16 caracteres');
      expect(validarNombre('dany!'), 'Solo letras, números y _');
      expect(validarNombre('mi nombre'), 'Solo letras, números y _');
    });
  });

  group('validarCorreo', () {
    test('acepta correos válidos', () {
      for (final correo in ['a@b.co', 'dany@correo.com', ' dany@correo.com ']) {
        expect(validarCorreo(correo), isNull, reason: correo);
      }
    });

    test('rechaza vacío y formatos incorrectos', () {
      expect(validarCorreo(''), 'Escribe tu correo');
      for (final correo in ['dany', 'dany@', 'dany@correo', '@correo.com']) {
        expect(validarCorreo(correo), 'Correo no válido', reason: correo);
      }
    });
  });

  group('validarContrasena', () {
    test('pide mínimo 6 caracteres', () {
      expect(validarContrasena(''), 'Escribe tu contraseña');
      expect(validarContrasena('12345'), 'Mínimo 6 caracteres');
      expect(validarContrasena('123456'), isNull);
    });

    test('acepta hasta 72 bytes en UTF-8', () {
      expect(validarContrasena('a' * 72), isNull);
      expect(validarContrasena('ñ' * 36), isNull); // 36 × 2 = 72 bytes
      expect(maximoBytesContrasena, 72);
    });

    test('rechaza más de 72 bytes, contando bytes y no letras', () {
      const mensaje = 'Máximo 72 bytes (las tildes y la ñ ocupan 2)';
      expect(validarContrasena('a' * 73), mensaje);
      // 37 letras pero 74 bytes.
      expect(validarContrasena('ñ' * 37), mensaje);
      // 71 letras ASCII + una tilde = 73 bytes.
      expect(validarContrasena('${'a' * 71}é'), mensaje);
    });
  });

  group('validarConfirmacion', () {
    test('debe coincidir con la contraseña', () {
      expect(validarConfirmacion('', 'abc123'), 'Repite tu contraseña');
      expect(
        validarConfirmacion('abc124', 'abc123'),
        'Las contraseñas no coinciden',
      );
      expect(validarConfirmacion('abc123', 'abc123'), isNull);
    });
  });
}