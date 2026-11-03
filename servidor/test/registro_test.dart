import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:test/test.dart';

import 'ayuda.dart';

void main() {
  late ServidorDePrueba servidor;

  setUp(() => servidor = ServidorDePrueba());
  tearDown(() => servidor.cerrar());

  group('POST /registro válido', () {
    test('crea la cuenta y responde 201 sin el hash', () async {
      final r = await servidor.registrar(correo: ' Dany@Correo.com ');

      expect(r.estado, 201);
      final usuario = r.json['usuario']! as Map<String, Object?>;
      expect(usuario['nombre'], 'dany');
      expect(usuario['correo'], 'dany@correo.com');
      expect(usuario['id'], isA<int>());
      expect(usuario.containsKey('hash'), isFalse);
      expect(usuario.containsKey('contrasena'), isFalse);
      expect(servidor.usuarios.cantidad, 1);
    });

    test('guarda un hash bcrypt, nunca la contraseña', () async {
      await servidor.registrar(contrasena: 'secreta1');

      final guardado = servidor.usuarios.porCorreo('dany@correo.com')!;
      expect(guardado.hash, startsWith(r'$2'));
      expect(guardado.hash, hasLength(60));
      expect(guardado.hash, isNot(contains('secreta1')));
      expect(
        await servidor.servicios.contrasenas.verificar(
          'secreta1',
          guardado.hash,
        ),
        isTrue,
      );
    });

    test('guarda la fecha de creación del reloj', () async {
      await servidor.registrar();
      expect(
        servidor.usuarios.porCorreo('dany@correo.com')!.creadoEn,
        servidor.reloj.ahora,
      );
    });

    test('acepta una contraseña de 72 bytes exactos', () async {
      final r = await servidor.registrar(contrasena: 'ñ' * 36);
      expect(r.estado, 201);
    });
  });

  group('Duplicados', () {
    test('correo repetido (aunque cambien mayúsculas): 409', () async {
      await servidor.registrar();
      final r = await servidor.registrar(
        nombre: 'otro',
        correo: 'DANY@correo.com',
      );

      expect(r.estado, 409);
      expect(r.error, 'Ese correo ya está registrado');
      expect(servidor.usuarios.cantidad, 1);
    });

    test('nombre repetido (aunque cambien mayúsculas): 409', () async {
      await servidor.registrar();
      final r = await servidor.registrar(
        nombre: 'DANY',
        correo: 'otro@correo.com',
      );

      expect(r.estado, 409);
      expect(r.error, 'Ese nombre de usuario ya está en uso');
      expect(servidor.usuarios.cantidad, 1);
    });
  });

  group('Datos inválidos: 400 con el mismo mensaje que la app', () {
    final casos = <String, (Map<String, Object?>, String)>{
      'sin nombre': (
        {'correo': 'a@b.co', 'contrasena': 'secreta1'},
        'Escribe tu nombre de usuario',
      ),
      'nombre corto': (
        {'nombre': 'ab', 'correo': 'a@b.co', 'contrasena': 'secreta1'},
        'Mínimo 3 caracteres',
      ),
      'nombre largo': (
        {'nombre': 'a' * 17, 'correo': 'a@b.co', 'contrasena': 'secreta1'},
        'Máximo 16 caracteres',
      ),
      'nombre con símbolos': (
        {'nombre': 'dany!', 'correo': 'a@b.co', 'contrasena': 'secreta1'},
        'Solo letras, números y _',
      ),
      'sin correo': (
        {'nombre': 'dany', 'contrasena': 'secreta1'},
        'Escribe tu correo',
      ),
      'correo mal escrito': (
        {'nombre': 'dany', 'correo': 'dany@', 'contrasena': 'secreta1'},
        'Correo no válido',
      ),
      'sin contraseña': (
        {'nombre': 'dany', 'correo': 'a@b.co'},
        'Escribe tu contraseña',
      ),
      'contraseña corta': (
        {'nombre': 'dany', 'correo': 'a@b.co', 'contrasena': '12345'},
        'Mínimo 6 caracteres',
      ),
      'contraseña de 73 bytes': (
        {'nombre': 'dany', 'correo': 'a@b.co', 'contrasena': 'a' * 73},
        'Máximo 72 bytes (las tildes y la ñ ocupan 2)',
      ),
      'contraseña de 37 eñes (74 bytes)': (
        {'nombre': 'dany', 'correo': 'a@b.co', 'contrasena': 'ñ' * 37},
        'Máximo 72 bytes (las tildes y la ñ ocupan 2)',
      ),
      'campos que no son texto': (
        {'nombre': 123, 'correo': true, 'contrasena': null},
        'Escribe tu nombre de usuario',
      ),
    };

    for (final MapEntry(key: caso, value: (cuerpo, mensaje)) in casos.entries) {
      test(caso, () async {
        final r = await servidor.pedir('POST', '/registro', cuerpo: cuerpo);
        expect(r.estado, 400);
        expect(r.error, mensaje);
        expect(servidor.usuarios.cantidad, 0);
      });
    }

    test('cuerpo que no es JSON', () async {
      final r = await servidor.pedir('POST', '/registro', cuerpo: '{nombre:');
      expect(r.estado, 400);
      expect(r.error, 'Datos inválidos');
    });

    test('JSON que no es un objeto', () async {
      final r = await servidor.pedir('POST', '/registro', cuerpo: '[1, 2]');
      expect(r.estado, 400);
      expect(r.error, 'Datos inválidos');
    });

    test('cuerpo demasiado grande: 413', () async {
      final r = await servidor.pedir(
        'POST',
        '/registro',
        cuerpo: {'nombre': 'a' * (maximoBytesCuerpo + 1)},
      );
      expect(r.estado, 413);
      expect(r.error, 'La petición es demasiado grande');
    });
  });

  group('Contraseñas (bcrypt)', () {
    final contrasenas = Contrasenas(costo: costoDePrueba);

    test('hashea, verifica la correcta y rechaza otra', () async {
      final hash = await contrasenas.hashear('secreta1');
      expect(await contrasenas.verificar('secreta1', hash), isTrue);
      expect(await contrasenas.verificar('Secreta1', hash), isFalse);
      expect(await contrasenas.verificar('', hash), isFalse);
    });

    test('la misma contraseña da hashes distintos (sal aleatoria)', () async {
      expect(
        await contrasenas.hashear('secreta1'),
        isNot(await contrasenas.hashear('secreta1')),
      );
    });

    test('usa el costo indicado', () async {
      final hash = await contrasenas.hashear('secreta1');
      expect(hash.substring(4, 7), r'04$');
    });

    test(
      'un hash dañado o una contraseña larga dan false, sin lanzar',
      () async {
        final hash = await contrasenas.hashear('secreta1');
        expect(
          await contrasenas.verificar('secreta1', 'no-es-un-hash'),
          isFalse,
        );
        expect(await contrasenas.verificar('a' * 73, hash), isFalse);
        expect(() => contrasenas.hashear('a' * 73), throwsArgumentError);
      },
    );
  });

  group('COSTO_BCRYPT', () {
    test('por defecto 10, y se puede cambiar', () {
      expect(Config.desde(variablesMinimas).costoBcrypt, 10);
      expect(
        Config.desde({...variablesMinimas, 'COSTO_BCRYPT': '12'}).costoBcrypt,
        12,
      );
    });

    test('fuera de rango no deja arrancar', () {
      for (final valor in ['3', '16', 'diez']) {
        expect(
          () => Config.desde({...variablesMinimas, 'COSTO_BCRYPT': valor}),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.mensaje,
              'mensaje',
              contains('COSTO_BCRYPT'),
            ),
          ),
        );
      }
    });

    test('en producción debe ser al menos 10', () {
      expect(
        () => Config.desde({
          ...variablesMinimas,
          'MODO': 'produccion',
          'ORIGENES_PERMITIDOS': 'https://a.com',
          'COSTO_BCRYPT': '8',
        }),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
