import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juego_brilliant/api_auth_repository.dart';
import 'package:juego_brilliant/auth_repository.dart';

const _usuarioJson = {'id': 1, 'nombre': 'dany', 'correo': 'dany@correo.com'};
const _tokenDePrueba = 'token.de.prueba';

http.Response _json(
  int estado,
  Object? cuerpo, {
  Map<String, String>? cabeceras,
}) => http.Response(
  cuerpo == null ? '' : jsonEncode(cuerpo),
  estado,
  headers: {'content-type': 'application/json; charset=utf-8', ...?cabeceras},
);

/// Respuesta de error como las del servidor.
http.Response _error(
  int estado,
  String mensaje, {
  Map<String, String>? cabeceras,
}) => _json(estado, {'error': mensaje}, cabeceras: cabeceras);

http.Response _sesionCorrecta() => _json(200, {
  'token': _tokenDePrueba,
  'expiraEn': '2026-11-04T13:00:00.000Z',
  'usuario': _usuarioJson,
});

/// Repositorio con un servidor falso. Guarda las peticiones recibidas.
class _Prueba {
  final recibidas = <http.Request>[];
  late final ApiAuthRepository repo;

  _Prueba(
    FutureOr<http.Response> Function(http.Request) responder, {
    Duration tiempoLimite = const Duration(seconds: 5),
  }) {
    repo = ApiAuthRepository(
      urlBase: 'http://servidor.prueba:8080',
      tiempoLimite: tiempoLimite,
      cliente: MockClient((peticion) async {
        recibidas.add(peticion);
        return responder(peticion);
      }),
    );
  }
}

Matcher _authError(String mensaje) =>
    throwsA(isA<AuthException>().having((e) => e.mensaje, 'mensaje', mensaje));

/// Inicia sesión contra un servidor que responde bien a /sesion y usa
/// [despues] para el resto.
Future<_Prueba> _conSesion(
  FutureOr<http.Response> Function(http.Request) despues,
) async {
  final prueba = _Prueba(
    (p) => p.url.path == '/sesion' ? _sesionCorrecta() : despues(p),
  );
  await prueba.repo.iniciarSesion(
    correo: 'dany@correo.com',
    contrasena: 'secreta1',
  );
  return prueba;
}

void main() {
  test('la dirección por defecto es el servidor local en el puerto 8080', () {
    expect(urlServidorPorDefecto, 'http://localhost:8080');
  });

  group('POST /registro', () {
    test('201 y después inicia sesión con /sesion', () async {
      final prueba = _Prueba(
        (p) => p.url.path == '/registro'
            ? _json(201, {'usuario': _usuarioJson})
            : _sesionCorrecta(),
      );

      final usuario = await prueba.repo.registrar(
        nombre: 'dany',
        correo: 'dany@correo.com',
        contrasena: 'secreta1',
      );

      expect(usuario, const Usuario(nombre: 'dany', correo: 'dany@correo.com'));
      expect(prueba.recibidas.map((p) => '${p.method} ${p.url}'), [
        'POST http://servidor.prueba:8080/registro',
        'POST http://servidor.prueba:8080/sesion',
      ]);
      final registro = prueba.recibidas.first;
      expect(registro.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(registro.body), {
        'nombre': 'dany',
        'correo': 'dany@correo.com',
        'contrasena': 'secreta1',
      });
      expect(prueba.repo.tieneToken, isTrue);
    });

    test('400: muestra el mensaje del servidor', () async {
      final prueba = _Prueba((_) => _error(400, 'Mínimo 6 caracteres'));
      await expectLater(
        prueba.repo.registrar(
          nombre: 'dany',
          correo: 'a@b.co',
          contrasena: '1',
        ),
        _authError('Mínimo 6 caracteres'),
      );
      expect(prueba.recibidas, hasLength(1));
    });

    test('409: correo o nombre duplicado', () async {
      for (final mensaje in [
        'Ese correo ya está registrado',
        'Ese nombre de usuario ya está en uso',
      ]) {
        final prueba = _Prueba((_) => _error(409, mensaje));
        await expectLater(
          prueba.repo.registrar(
            nombre: 'dany',
            correo: 'a@b.co',
            contrasena: 'secreta1',
          ),
          _authError(mensaje),
        );
      }
    });

    test('413: datos demasiado grandes', () async {
      final prueba = _Prueba(
        (_) => _error(413, 'La petición es demasiado grande'),
      );
      await expectLater(
        prueba.repo.registrar(
          nombre: 'dany',
          correo: 'a@b.co',
          contrasena: 'secreta1',
        ),
        _authError('Los datos enviados son demasiado grandes.'),
      );
    });

    test('429: dice cuántos segundos esperar según Retry-After', () async {
      final prueba = _Prueba(
        (_) => _error(
          429,
          'Demasiados intentos.',
          cabeceras: {'retry-after': '42'},
        ),
      );
      await expectLater(
        prueba.repo.registrar(
          nombre: 'dany',
          correo: 'a@b.co',
          contrasena: 'secreta1',
        ),
        _authError(
          'Demasiados intentos. Espera 42 segundos e inténtalo de nuevo.',
        ),
      );
    });
  });

  group('POST /sesion', () {
    test('200: guarda el token y devuelve el usuario', () async {
      final prueba = _Prueba((_) => _sesionCorrecta());
      final usuario = await prueba.repo.iniciarSesion(
        correo: 'dany@correo.com',
        contrasena: 'secreta1',
      );

      expect(usuario.nombre, 'dany');
      expect(prueba.repo.tieneToken, isTrue);
      expect(jsonDecode(prueba.recibidas.single.body), {
        'correo': 'dany@correo.com',
        'contrasena': 'secreta1',
      });
    });

    test('401: credenciales incorrectas (no es sesión vencida)', () async {
      final prueba = _Prueba(
        (_) => _error(401, 'Correo o contraseña incorrectos'),
      );
      final intento = prueba.repo.iniciarSesion(
        correo: 'a@b.co',
        contrasena: 'mala12',
      );

      await expectLater(intento, _authError('Correo o contraseña incorrectos'));
      await expectLater(intento, throwsA(isNot(isA<SesionVencidaException>())));
      expect(prueba.repo.tieneToken, isFalse);
    });

    test('429 de un segundo usa el singular', () async {
      final prueba = _Prueba(
        (_) => _error(429, 'x', cabeceras: {'retry-after': '1'}),
      );
      await expectLater(
        prueba.repo.iniciarSesion(correo: 'a@b.co', contrasena: 'secreta1'),
        _authError(
          'Demasiados intentos. Espera 1 segundo e inténtalo de nuevo.',
        ),
      );
    });

    test('429 sin Retry-After da un mensaje sin número', () async {
      final prueba = _Prueba((_) => _error(429, 'x'));
      await expectLater(
        prueba.repo.iniciarSesion(correo: 'a@b.co', contrasena: 'secreta1'),
        _authError(
          'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
        ),
      );
    });

    test('500: error del servidor sin detalles', () async {
      final prueba = _Prueba((_) => _error(500, 'Error interno del servidor'));
      await expectLater(
        prueba.repo.iniciarSesion(correo: 'a@b.co', contrasena: 'secreta1'),
        _authError('El servidor tuvo un problema. Inténtalo más tarde.'),
      );
    });

    test('200 sin token o con un cuerpo raro: respuesta inesperada', () async {
      for (final respuesta in [
        _json(200, {'usuario': _usuarioJson}),
        http.Response('no es json', 200),
        _json(200, {'token': _tokenDePrueba}),
      ]) {
        final prueba = _Prueba((_) => respuesta);
        await expectLater(
          prueba.repo.iniciarSesion(correo: 'a@b.co', contrasena: 'secreta1'),
          _authError('El servidor respondió algo inesperado.'),
        );
        expect(prueba.repo.tieneToken, isFalse);
      }
    });
  });

  group('Sin servidor', () {
    test('sin conexión: mensaje claro y tipo ServidorNoDisponible', () async {
      final prueba = _Prueba(
        (_) => throw http.ClientException('Connection refused'),
      );
      final intento = prueba.repo.iniciarSesion(
        correo: 'a@b.co',
        contrasena: 'secreta1',
      );

      await expectLater(
        intento,
        _authError(
          'No se pudo conectar con el servidor. Revisa tu conexión o inténtalo más tarde.',
        ),
      );
      await expectLater(intento, throwsA(isA<ServidorNoDisponibleException>()));
    });

    test('tiempo agotado: mensaje claro', () async {
      final prueba = _Prueba((_) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        return _sesionCorrecta();
      }, tiempoLimite: const Duration(milliseconds: 50));

      await expectLater(
        prueba.repo.iniciarSesion(correo: 'a@b.co', contrasena: 'secreta1'),
        throwsA(
          isA<ServidorNoDisponibleException>().having(
            (e) => e.mensaje,
            'mensaje',
            'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
          ),
        ),
      );
    });
  });

  group('GET /cuenta (restaurar sesión)', () {
    test('sin token no llama al servidor y devuelve null', () async {
      final prueba = _Prueba((_) => fail('no debía llamar'));
      expect(await prueba.repo.restaurarSesion(), isNull);
      expect(prueba.recibidas, isEmpty);
    });

    test('200: devuelve el usuario y manda el token', () async {
      final prueba = await _conSesion(
        (_) => _json(200, {'usuario': _usuarioJson}),
      );

      final usuario = await prueba.repo.restaurarSesion();

      expect(usuario?.correo, 'dany@correo.com');
      final cuenta = prueba.recibidas.last;
      expect('${cuenta.method} ${cuenta.url.path}', 'GET /cuenta');
      expect(cuenta.headers['authorization'], 'Bearer $_tokenDePrueba');
    });

    test('401: borra el token y devuelve null', () async {
      final prueba = await _conSesion(
        (_) => _error(401, 'Tu sesión no es válida o ya venció'),
      );

      expect(await prueba.repo.restaurarSesion(), isNull);
      expect(prueba.repo.tieneToken, isFalse);
    });

    test('sin conexión: lanza el error y conserva el token', () async {
      final prueba = await _conSesion(
        (_) => throw http.ClientException('sin red'),
      );

      await expectLater(
        prueba.repo.restaurarSesion(),
        throwsA(isA<ServidorNoDisponibleException>()),
      );
      expect(prueba.repo.tieneToken, isTrue);
    });
  });

  group('DELETE /cuenta', () {
    test('204: manda token y contraseña, y olvida el token', () async {
      final prueba = await _conSesion((_) => http.Response('', 204));

      await prueba.repo.borrarCuenta('secreta1');

      final borrar = prueba.recibidas.last;
      expect('${borrar.method} ${borrar.url.path}', 'DELETE /cuenta');
      expect(borrar.headers['authorization'], 'Bearer $_tokenDePrueba');
      expect(jsonDecode(borrar.body), {'contrasena': 'secreta1'});
      expect(prueba.repo.tieneToken, isFalse);
    });

    test('403: contraseña incorrecta, NO es sesión vencida', () async {
      final prueba = await _conSesion(
        (_) => _error(403, 'La contraseña no es correcta'),
      );
      final intento = prueba.repo.borrarCuenta('mala12');

      await expectLater(intento, _authError('La contraseña no es correcta'));
      await expectLater(intento, throwsA(isNot(isA<SesionVencidaException>())));
      expect(prueba.repo.tieneToken, isTrue);
    });

    test('401: sesión vencida, borra el token', () async {
      final prueba = await _conSesion(
        (_) => _error(401, 'Tu sesión no es válida o ya venció'),
      );

      await expectLater(
        prueba.repo.borrarCuenta('secreta1'),
        throwsA(isA<SesionVencidaException>()),
      );
      expect(prueba.repo.tieneToken, isFalse);
    });

    test('sin token: sesión vencida sin llamar al servidor', () async {
      final prueba = _Prueba((_) => fail('no debía llamar'));
      await expectLater(
        prueba.repo.borrarCuenta('secreta1'),
        throwsA(isA<SesionVencidaException>()),
      );
      expect(prueba.recibidas, isEmpty);
    });

    test('429 y 400 con sus mensajes, conservando el token', () async {
      final limite = await _conSesion(
        (_) => _error(429, 'x', cabeceras: {'retry-after': '300'}),
      );
      await expectLater(
        limite.repo.borrarCuenta('mala12'),
        _authError(
          'Demasiados intentos. Espera 300 segundos e inténtalo de nuevo.',
        ),
      );
      expect(limite.repo.tieneToken, isTrue);

      final datos = await _conSesion((_) => _error(400, 'Datos inválidos'));
      await expectLater(
        datos.repo.borrarCuenta(''),
        _authError('Datos inválidos'),
      );
    });
  });

  test('cerrar sesión olvida el token', () async {
    final prueba = await _conSesion((_) => fail('no debía llamar'));
    await prueba.repo.cerrarSesion();
    expect(prueba.repo.tieneToken, isFalse);
    expect(await prueba.repo.restaurarSesion(), isNull);
  });

  test('la dirección acepta barra final', () async {
    final peticiones = <Uri>[];
    final repo = ApiAuthRepository(
      urlBase: 'https://brilliant.ejemplo.com/api/',
      cliente: MockClient((p) async {
        peticiones.add(p.url);
        return _sesionCorrecta();
      }),
    );
    await repo.iniciarSesion(correo: 'a@b.co', contrasena: 'secreta1');
    expect(
      peticiones.single.toString(),
      'https://brilliant.ejemplo.com/api/sesion',
    );
  });
}
