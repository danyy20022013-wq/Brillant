import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:test/test.dart';

import 'ayuda.dart';

/// Parte de un JWT en base64url sin relleno.
String _b64(Map<String, Object?> datos) =>
    base64Url.encode(utf8.encode(jsonEncode(datos))).replaceAll('=', '');

void main() {
  late ServidorDePrueba servidor;

  setUp(() async {
    servidor = ServidorDePrueba();
    await servidor.registrar();
  });
  tearDown(() => servidor.cerrar());

  Future<Respuesta> iniciar({
    String correo = 'dany@correo.com',
    String contrasena = 'secreta1',
    String ip = '10.0.0.1',
  }) => servidor.pedir(
    'POST',
    '/sesion',
    ip: ip,
    cuerpo: {'correo': correo, 'contrasena': contrasena},
  );

  Future<String> token() async => (await iniciar()).json['token']! as String;

  Future<Respuesta> cuenta(String? token) =>
      servidor.pedir('GET', '/cuenta', token: token);

  group('POST /sesion', () {
    test('login correcto: token, vencimiento a 1 hora y usuario', () async {
      final r = await iniciar(correo: '  DANY@correo.com ');

      expect(r.estado, 200);
      expect(r.json['token'], isA<String>());
      expect(
        DateTime.parse(r.json['expiraEn']! as String),
        servidor.reloj.ahora.add(const Duration(hours: 1)),
      );
      final usuario = r.json['usuario']! as Map<String, Object?>;
      expect(usuario['nombre'], 'dany');
      expect(usuario.containsKey('hash'), isFalse);
    });

    test('el token es HS256 y no lleva datos de más', () async {
      final partes = (await token()).split('.');
      final cabecera = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(partes[0]))),
      );
      final datos = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))),
      );
      expect(cabecera, {'alg': 'HS256', 'typ': 'JWT'});
      expect((datos as Map).keys.toSet(), {'sub', 'iat', 'exp'});
    });

    test(
      'correo inexistente y contraseña incorrecta dan el mismo error',
      () async {
        final noExiste = await iniciar(correo: 'nadie@correo.com');
        final incorrecta = await iniciar(contrasena: 'otra-clave');

        expect(noExiste.estado, 401);
        expect(incorrecta.estado, 401);
        expect(noExiste.cuerpo, incorrecta.cuerpo);
        expect(noExiste.error, 'Correo o contraseña incorrectos');
        expect(noExiste.cabeceras, incorrecta.cabeceras);
      },
    );

    test('faltan campos o no son texto: 400', () async {
      for (final cuerpo in [
        <String, Object?>{},
        {'correo': 'dany@correo.com'},
        {'correo': 1, 'contrasena': 'secreta1'},
      ]) {
        final r = await servidor.pedir('POST', '/sesion', cuerpo: cuerpo);
        expect(r.estado, 400, reason: '$cuerpo');
        expect(r.error, 'Datos inválidos');
      }
    });
  });

  group('Límite de intentos', () {
    test(
      '5 fallos del mismo correo bloquean, incluso la clave correcta',
      () async {
        for (var i = 0; i < 5; i++) {
          expect(
            (await iniciar(contrasena: 'mala$i', ip: '10.0.0.${i + 2}')).estado,
            401,
          );
        }

        final bloqueado = await iniciar(ip: '10.0.0.99');
        expect(bloqueado.estado, 429);
        expect(bloqueado.error, startsWith('Demasiados intentos'));
        expect(
          int.parse(bloqueado.cabeceras['retry-after']!),
          inInclusiveRange(1, 15 * 60),
        );
      },
    );

    test('al pasar los 15 minutos se puede volver a intentar', () async {
      for (var i = 0; i < 5; i++) {
        await iniciar(contrasena: 'mala');
      }
      expect((await iniciar()).estado, 429);

      servidor.reloj.avanzar(const Duration(minutes: 15, seconds: 1));
      expect((await iniciar()).estado, 200);
    });

    test('Retry-After dice cuánto falta de verdad', () async {
      for (var i = 0; i < 5; i++) {
        await iniciar(contrasena: 'mala');
      }
      servidor.reloj.avanzar(const Duration(minutes: 10));
      final r = await iniciar();
      expect(r.cabeceras['retry-after'], '${5 * 60}');
      expect(r.error, 'Demasiados intentos. Prueba de nuevo en 5 minutos.');
    });

    test('un login correcto reinicia el contador de ese correo', () async {
      for (var i = 0; i < 4; i++) {
        await iniciar(contrasena: 'mala', ip: '10.0.1.$i');
      }
      expect((await iniciar(ip: '10.0.2.1')).estado, 200);

      // Se cuentan desde cero: 4 fallos más todavía no bloquean.
      for (var i = 0; i < 4; i++) {
        await iniciar(contrasena: 'mala', ip: '10.0.3.$i');
      }
      expect((await iniciar(ip: '10.0.4.1')).estado, 200);
    });

    test(
      '5 fallos desde la misma IP bloquean esa IP con otros correos',
      () async {
        for (var i = 0; i < 5; i++) {
          await iniciar(correo: 'otro$i@correo.com', ip: '10.9.9.9');
        }

        expect((await iniciar(ip: '10.9.9.9')).estado, 429);
        // Otra IP con el correo real sigue funcionando.
        expect((await iniciar(ip: '10.8.8.8')).estado, 200);
      },
    );

    test('/registro también se limita por IP', () async {
      // El setUp ya hizo 1 registro desde 10.0.0.1.
      for (var i = 0; i < 4; i++) {
        final r = await servidor.registrar(
          nombre: 'jugador$i',
          correo: 'j$i@correo.com',
        );
        expect(r.estado, 201);
      }
      final sexto = await servidor.registrar(
        nombre: 'jugador9',
        correo: 'j9@c.com',
      );
      expect(sexto.estado, 429);
      expect(sexto.cabeceras['retry-after'], isNotNull);

      // Otra IP puede registrarse.
      final otraIp = await servidor.registrar(
        nombre: 'jugador9',
        correo: 'j9@c.com',
        ip: '10.0.0.50',
      );
      expect(otraIp.estado, 201);
    });
  });

  group('GET /cuenta y tokens', () {
    test('con un token válido devuelve el usuario', () async {
      final r = await cuenta(await token());
      expect(r.estado, 200);
      expect((r.json['usuario']! as Map)['correo'], 'dany@correo.com');
    });

    test('sin token, o con una cabecera mal formada: 401', () async {
      final sinToken = await cuenta(null);
      expect(sinToken.estado, 401);
      expect(sinToken.error, 'Tu sesión no es válida o ya venció');
      expect(sinToken.cabeceras['www-authenticate'], 'Bearer');

      for (final cabecera in ['Bearer', 'Basic abc', 'Bearer ', 'abc']) {
        final r = await servidor.pedir(
          'GET',
          '/cuenta',
          cabeceras: {'authorization': cabecera},
        );
        expect(r.estado, 401, reason: cabecera);
      }
    });

    test('token vencido: vale hasta la hora y después no', () async {
      final t = await token();

      servidor.reloj.avanzar(const Duration(minutes: 59, seconds: 59));
      expect((await cuenta(t)).estado, 200);

      servidor.reloj.avanzar(const Duration(seconds: 1));
      final vencido = await cuenta(t);
      expect(vencido.estado, 401);
      expect(vencido.error, 'Tu sesión no es válida o ya venció');
    });

    test('token manipulado (otro usuario en el contenido): 401', () async {
      final otro = await servidor.registrar(
        nombre: 'otro',
        correo: 'otro@correo.com',
        ip: '10.0.0.7',
      );
      final idOtro = (otro.json['usuario']! as Map)['id'];

      final partes = (await token()).split('.');
      final datos =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))),
              )
              as Map<String, Object?>;
      datos['sub'] = '$idOtro';
      final manipulado = '${partes[0]}.${_b64(datos)}.${partes[2]}';

      expect((await cuenta(manipulado)).estado, 401);
    });

    test('token firmado con otra clave: 401', () async {
      final ajeno = JWT({
        'sub': '1',
        'exp': servidor.reloj.ahora.millisecondsSinceEpoch ~/ 1000 + 3600,
      }).sign(SecretKey('otra-clave-falsa-de-32-bytes-o-mas!!'));
      expect((await cuenta(ajeno)).estado, 401);
    });

    test('token con algoritmo "none": 401', () async {
      final exp = servidor.reloj.ahora.millisecondsSinceEpoch ~/ 1000 + 3600;
      final sinFirma =
          '${_b64({'alg': 'none', 'typ': 'JWT'})}.'
          '${_b64({'sub': '1', 'exp': exp})}.';
      expect((await cuenta(sinFirma)).estado, 401);

      final conNone =
          '${_b64({'alg': 'none', 'typ': 'JWT'})}.'
          '${_b64({'sub': '1', 'exp': exp})}.firma';
      expect((await cuenta(conNone)).estado, 401);
    });

    test('token con nuestra clave pero otro algoritmo (HS512): 401', () async {
      final exp = servidor.reloj.ahora.millisecondsSinceEpoch ~/ 1000 + 3600;
      final hs512 = JWT({
        'sub': '1',
        'exp': exp,
      }).sign(SecretKey(secretoDePrueba), algorithm: JWTAlgorithm.HS512);
      expect((await cuenta(hs512)).estado, 401);
    });

    test('token con nuestra clave pero sin vencimiento: 401', () async {
      final sinExp = JWT({
        'sub': '1',
      }).sign(SecretKey(secretoDePrueba), noIssueAt: true);
      expect((await cuenta(sinExp)).estado, 401);
    });

    test('token de una cuenta borrada ya no sirve', () async {
      final t = await token();
      final id = servidor.usuarios.porCorreo('dany@correo.com')!.id;
      servidor.usuarios.borrar(id);

      expect((await cuenta(t)).estado, 401);
    });

    test('basura en vez de token: 401', () async {
      for (final basura in ['x', 'a.b.c', '...', 'ñ.ñ.ñ']) {
        expect((await cuenta(basura)).estado, 401, reason: basura);
      }
    });
  });

  group('JWT_SECRETO', () {
    test('si falta, el servidor no arranca y explica por qué', () {
      expect(
        () => Config.desde({}),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('Falta JWT_SECRETO'),
          ),
        ),
      );
      expect(
        () => Config.desde({'JWT_SECRETO': '   '}),
        throwsA(isA<ConfigException>()),
      );
    });

    test('si es corta (menos de 32 bytes) no arranca', () {
      expect(
        () => Config.desde({'JWT_SECRETO': 'a' * 31}),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('demasiado corta'),
          ),
        ),
      );
      expect(Config.desde({'JWT_SECRETO': 'a' * 32}).jwtSecreto, 'a' * 32);
    });

    test('Tokens también rechaza una clave corta', () {
      expect(
        () => Tokens(secreto: 'corta', reloj: relojDelSistema),
        throwsArgumentError,
      );
    });
  });
}
