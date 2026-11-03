import 'package:test/test.dart';

import 'ayuda.dart';

void main() {
  late ServidorDePrueba servidor;

  setUp(() async {
    servidor = ServidorDePrueba();
    await servidor.registrar();
    await servidor.registrar(
      nombre: 'bea',
      correo: 'bea@correo.com',
      contrasena: 'clave-bea',
      ip: '10.0.0.2',
    );
  });
  tearDown(() => servidor.cerrar());

  Future<String> token(String correo, String contrasena) async {
    final r = await servidor.pedir(
      'POST',
      '/sesion',
      cuerpo: {'correo': correo, 'contrasena': contrasena},
    );
    return r.json['token']! as String;
  }

  Future<String> tokenDany() => token('dany@correo.com', 'secreta1');
  Future<String> tokenBea() => token('bea@correo.com', 'clave-bea');

  Future<Respuesta> borrar(String? token, Object? cuerpo) =>
      servidor.pedir('DELETE', '/cuenta', token: token, cuerpo: cuerpo);

  bool existe(String correo) => servidor.usuarios.porCorreo(correo) != null;

  test(
    'con el token y la contraseña correcta: 204 y la cuenta se borra',
    () async {
      final r = await borrar(await tokenDany(), {'contrasena': 'secreta1'});

      expect(r.estado, 204);
      expect(r.cuerpo, isNull);
      expect(existe('dany@correo.com'), isFalse);
      expect(existe('bea@correo.com'), isTrue);
    },
  );

  test('después de borrar, el token deja de servir', () async {
    final t = await tokenDany();
    await borrar(t, {'contrasena': 'secreta1'});

    final cuenta = await servidor.pedir('GET', '/cuenta', token: t);
    expect(cuenta.estado, 401);
    expect(cuenta.error, 'Tu sesión no es válida o ya venció');

    final otraVez = await borrar(t, {'contrasena': 'secreta1'});
    expect(otraVez.estado, 401);
  });

  test('después de borrar, iniciar sesión da el error genérico', () async {
    await borrar(await tokenDany(), {'contrasena': 'secreta1'});

    final r = await servidor.pedir(
      'POST',
      '/sesion',
      cuerpo: {'correo': 'dany@correo.com', 'contrasena': 'secreta1'},
    );
    expect(r.estado, 401);
    expect(r.error, 'Correo o contraseña incorrectos');
  });

  test('con la contraseña incorrecta: 403 y la cuenta sigue', () async {
    final r = await borrar(await tokenDany(), {'contrasena': 'otra-clave'});

    expect(r.estado, 403);
    expect(r.error, 'La contraseña no es correcta');
    expect(existe('dany@correo.com'), isTrue);
  });

  test('token de otra persona: no se puede borrar una cuenta ajena', () async {
    // El token decide qué cuenta se borra (la de Bea), y la contraseña
    // tiene que ser la de esa cuenta. Aunque Bea supiera la contraseña de
    // Dany, con su token no puede borrar la cuenta de Dany.
    final deBea = await tokenBea();

    final conClaveDeDany = await borrar(deBea, {'contrasena': 'secreta1'});
    expect(conClaveDeDany.estado, 403);
    expect(existe('dany@correo.com'), isTrue);
    expect(existe('bea@correo.com'), isTrue);

    // Con su propia contraseña, Bea solo puede borrar SU cuenta.
    final conSuClave = await borrar(deBea, {'contrasena': 'clave-bea'});
    expect(conSuClave.estado, 204);
    expect(existe('bea@correo.com'), isFalse);
    expect(existe('dany@correo.com'), isTrue);
  });

  test('sin token o con token vencido: 401', () async {
    expect((await borrar(null, {'contrasena': 'secreta1'})).estado, 401);

    final t = await tokenDany();
    servidor.reloj.avanzar(const Duration(hours: 1));
    expect((await borrar(t, {'contrasena': 'secreta1'})).estado, 401);
    expect(existe('dany@correo.com'), isTrue);
  });

  test('sin contraseña o con un cuerpo inválido: 400', () async {
    final t = await tokenDany();
    expect((await borrar(t, <String, Object?>{})).estado, 400);
    expect((await borrar(t, {'contrasena': 123})).estado, 400);
    expect((await borrar(t, 'no es json')).estado, 400);
    expect(existe('dany@correo.com'), isTrue);
  });

  test('5 contraseñas incorrectas bloquean el borrado (429)', () async {
    final t = await tokenDany();
    for (var i = 0; i < 5; i++) {
      expect((await borrar(t, {'contrasena': 'mala$i'})).estado, 403);
    }
    final bloqueado = await borrar(t, {'contrasena': 'secreta1'});
    expect(bloqueado.estado, 429);
    expect(bloqueado.cabeceras['retry-after'], isNotNull);
    expect(existe('dany@correo.com'), isTrue);
  });

  test('se puede registrar de nuevo con los mismos datos', () async {
    final viejo = await tokenDany();
    final idViejo = servidor.usuarios.porCorreo('dany@correo.com')!.id;
    await borrar(viejo, {'contrasena': 'secreta1'});

    final r = await servidor.registrar(ip: '10.0.0.3');
    expect(r.estado, 201);
    final idNuevo = (r.json['usuario']! as Map)['id']! as int;
    expect(idNuevo, greaterThan(idViejo));

    // El token de la cuenta borrada no sirve para la cuenta nueva...
    expect((await servidor.pedir('GET', '/cuenta', token: viejo)).estado, 401);
    // ...pero un token nuevo sí.
    final nuevo = await tokenDany();
    final cuenta = await servidor.pedir('GET', '/cuenta', token: nuevo);
    expect(cuenta.estado, 200);
    expect((cuenta.json['usuario']! as Map)['id'], idNuevo);
  });

  test('CORS deja pasar DELETE con Authorization desde localhost', () async {
    final previa = await servidor.pedir(
      'OPTIONS',
      '/cuenta',
      cabeceras: {
        'origin': 'http://localhost:5000',
        'access-control-request-method': 'DELETE',
        'access-control-request-headers': 'authorization,content-type',
      },
    );
    expect(previa.estado, 204);
    expect(
      previa.cabeceras['access-control-allow-methods'],
      contains('DELETE'),
    );
    expect(
      previa.cabeceras['access-control-allow-headers'],
      contains('Authorization'),
    );
  });
}
