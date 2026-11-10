import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:test/test.dart';

import 'ayuda_multijugador.dart';

void main() {
  late Mesa mesa;

  setUp(() => mesa = Mesa());
  tearDown(() => mesa.cerrar());

  group('crear sala', () {
    test('devuelve un código de 6 caracteres y el estado del lobby', () {
      final ana = mesa.entrar('ana');
      ana.accion('crear_sala', {'mapa': 3, 'maximo': 4});

      final sala = ana.sala;
      final codigo = sala['codigo']! as String;
      expect(codigo.length, 6);
      expect(normalizarCodigoSala(codigo), codigo);
      expect(sala['mapa'], 3);
      expect(sala['maximo'], 4);
      expect(sala['fase'], 'lobby');
      expect(sala['anfitrion'], mesa.idDe('ana'));
      expect(sala['segundosParaCaducar'], 15 * 60);
      expect(sala.jugadores, [
        {
          'id': mesa.idDe('ana'),
          'nombre': 'ana',
          'anfitrion': true,
          'listo': false,
          'enSala': true,
          'conectado': true,
        },
      ]);
      expect(mesa.mj.codigoDeSalaDe(mesa.idDe('ana')), codigo);
    });

    test('valida el mapa y el máximo', () {
      final ana = mesa.entrar('ana');
      for (final (datos, codigo) in [
        ({'mapa': 0, 'maximo': 2}, 'mapa_invalido'),
        ({'mapa': 5, 'maximo': 2}, 'mapa_invalido'),
        ({'mapa': '1', 'maximo': 2}, 'mapa_invalido'),
        ({'mapa': 1, 'maximo': 1}, 'maximo_invalido'),
        ({'mapa': 1, 'maximo': 5}, 'maximo_invalido'),
        ({'mapa': 1}, 'maximo_invalido'),
      ]) {
        final id = ana.accion('crear_sala', datos);
        expect(ana.ultimoError!['codigo'], codigo, reason: '$datos');
        expect(ana.ultimoError!['id'], id);
      }
      expect(mesa.mj.cantidadSalas, 0);
    });

    test('cada sala tiene su propio código', () {
      final codigos = <String>{};
      for (var i = 0; i < 20; i++) {
        final c = mesa.entrar('j$i');
        c.accion('crear_sala', {'mapa': 1, 'maximo': 2});
        codigos.add(c.sala['codigo']! as String);
      }
      expect(codigos.length, 20);
    });

    test('no se puede crear otra estando en una sala', () {
      final ana = mesa.entrar('ana');
      ana.accion('crear_sala', {'mapa': 1, 'maximo': 2});
      ana.accion('crear_sala', {'mapa': 2, 'maximo': 2});
      expect(ana.ultimoError!['codigo'], 'ya_en_sala');
      expect(mesa.mj.cantidadSalas, 1);
    });
  });

  group('unirse', () {
    test('entra al lobby y todos reciben la lista de jugadores', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      ana.accion('crear_sala', {'mapa': 1, 'maximo': 3});
      final codigo = ana.sala['codigo']! as String;

      beto.accion('unirse', {'codigo': codigo.toLowerCase()});

      for (final c in [ana, beto]) {
        expect(c.sala.jugadores.map((j) => (j['nombre'], j['anfitrion'])), [
          ('ana', true),
          ('beto', false),
        ]);
      }
    });

    test('código inexistente', () {
      final beto = mesa.entrar('beto');
      beto.accion('unirse', {'codigo': 'ZZZZZZ'});
      expect(beto.ultimoError!['codigo'], 'sala_inexistente');
      beto.accion('unirse', {'codigo': 'mal'});
      expect(beto.ultimoError!['codigo'], 'sala_inexistente');
      beto.accion('unirse', {});
      expect(beto.ultimoError!['codigo'], 'sala_inexistente');
      expect(beto.ultimoError!['mensaje'], 'No existe una sala con ese código');
    });

    test('sala llena', () {
      final ana = mesa.entrar('ana');
      final codigo = mesa.salaCon([ana, mesa.entrar('beto')], maximo: 2);
      final cami = mesa.entrar('cami');
      cami.accion('unirse', {'codigo': codigo});
      expect(cami.ultimoError!['codigo'], 'sala_llena');
    });

    test('sala ya iniciada', () {
      final codigo = mesa.partidaCon([mesa.entrar('ana'), mesa.entrar('beto')]);
      final cami = mesa.entrar('cami');
      cami.accion('unirse', {'codigo': codigo});
      expect(cami.ultimoError!['codigo'], 'sala_iniciada');
    });

    test('ya está en otra sala', () {
      final ana = mesa.entrar('ana');
      final codigo = mesa.salaCon([ana, mesa.entrar('beto')]);
      final cami = mesa.entrar('cami');
      cami.accion('crear_sala', {'mapa': 1, 'maximo': 2});
      cami.accion('unirse', {'codigo': codigo});
      expect(cami.ultimoError!['codigo'], 'ya_en_sala');
    });

    test('unirse a la sala en la que ya está solo reenvía el estado', () {
      final ana = mesa.entrar('ana');
      final codigo = mesa.salaCon([ana, mesa.entrar('beto')]);
      ana.olvidar();
      ana.accion('unirse', {'codigo': codigo});
      expect(ana.ultimoError, isNull);
      expect(ana.sala.jugadores.length, 2);
    });

    test('límite de intentos por usuario', () {
      final ana = mesa.entrar('ana');
      for (var i = 0; i < 10; i++) {
        ana.accion('unirse', {'codigo': 'ZZZZZZ'});
        expect(ana.ultimoError!['codigo'], 'sala_inexistente');
      }
      ana.accion('unirse', {'codigo': 'ZZZZZZ'});
      expect(ana.ultimoError!['codigo'], 'demasiados_intentos');
      expect(ana.ultimoError!['mensaje'], contains('Espera 60 segundos'));

      // Pasado el minuto puede volver a intentar.
      mesa.programador.avanzar(const Duration(minutes: 1));
      ana.accion('unirse', {'codigo': 'ZZZZZZ'});
      expect(ana.ultimoError!['codigo'], 'sala_inexistente');
    });

    test('límite de intentos por IP aunque cambie de cuenta', () {
      for (var i = 0; i < 30; i++) {
        final c = mesa.entrar('j${i ~/ 5}', ip: '10.9.9.9');
        c.siguienteId = 100 + i; // ids crecientes por cuenta
        c.accion('unirse', {'codigo': 'ZZZZZZ'});
      }
      final otro = mesa.entrar('nuevo', ip: '10.9.9.9');
      otro.accion('unirse', {'codigo': 'ZZZZZZ'});
      expect(otro.ultimoError!['codigo'], 'demasiados_intentos');

      // Desde otra IP no hay bloqueo.
      final lejos = mesa.entrar('lejos', ip: '10.1.1.1');
      lejos.accion('unirse', {'codigo': 'ZZZZZZ'});
      expect(lejos.ultimoError!['codigo'], 'sala_inexistente');
    });
  });

  group('lobby', () {
    test('listo y no listo', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      mesa.salaCon([ana, beto]);
      beto.accion('listo', {'listo': true});
      expect(ana.sala.jugador(mesa.idDe('beto'))['listo'], isTrue);
      beto.accion('listo', {'listo': false});
      expect(ana.sala.jugador(mesa.idDe('beto'))['listo'], isFalse);
      beto.accion('listo', {'listo': 'si'});
      expect(beto.ultimoError!['codigo'], 'mensaje_invalido');
    });

    test('salir avisa al que sale y a los demás', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      final codigo = mesa.salaCon([ana, beto]);
      beto.accion('salir');
      expect(beto.ultimo('saliste')!['codigo'], codigo);
      expect(ana.sala.jugadores.length, 1);
      expect(mesa.mj.codigoDeSalaDe(mesa.idDe('beto')), isNull);
      // Ya puede crear otra sala.
      beto.accion('crear_sala', {'mapa': 1, 'maximo': 2});
      expect(beto.ultimoError, isNull);
    });

    test('si el anfitrión sale, el siguiente pasa a ser anfitrión', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      final cami = mesa.entrar('cami');
      mesa.salaCon([ana, beto, cami]);
      ana.accion('salir');
      expect(beto.sala['anfitrion'], mesa.idDe('beto'));
      expect(cami.sala.jugador(mesa.idDe('beto'))['anfitrion'], isTrue);
    });

    test('la sala vacía se borra', () {
      final ana = mesa.entrar('ana');
      final codigo = mesa.salaCon([ana]);
      ana.accion('salir');
      expect(mesa.mj.sala(codigo), isNull);
      expect(mesa.mj.cantidadSalas, 0);
    });

    test('salir sin estar en una sala da error', () {
      final ana = mesa.entrar('ana');
      ana.accion('salir');
      expect(ana.ultimoError!['codigo'], 'no_en_sala');
    });

    test('las salas en lobby caducan a los 15 minutos', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      final codigo = mesa.salaCon([ana, beto]);
      mesa.programador.avanzar(const Duration(minutes: 14, seconds: 59));
      expect(mesa.mj.sala(codigo), isNotNull);
      mesa.programador.avanzar(const Duration(seconds: 1));
      expect(mesa.mj.sala(codigo), isNull);
      for (final c in [ana, beto]) {
        expect(c.ultimo('sala_cerrada')!['motivo'], 'caducada');
      }
      expect(mesa.mj.codigoDeSalaDe(mesa.idDe('ana')), isNull);
    });

    test('una sala que ya empezó no caduca', () {
      final codigo = mesa.partidaCon([mesa.entrar('ana'), mesa.entrar('beto')]);
      mesa.programador.avanzar(const Duration(minutes: 16));
      expect(mesa.mj.sala(codigo), isNotNull);
    });
  });

  group('iniciar', () {
    test('solo el anfitrión', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      mesa.salaCon([ana, beto]);
      ana.accion('listo', {'listo': true});
      beto.accion('listo', {'listo': true});
      beto.accion('iniciar');
      expect(beto.ultimoError!['codigo'], 'no_eres_anfitrion');
      ana.accion('iniciar');
      expect(ana.sala['fase'], 'numeros');
      expect(beto.sala['fase'], 'numeros');
    });

    test('con 2 o más jugadores', () {
      final ana = mesa.entrar('ana');
      ana.accion('crear_sala', {'mapa': 1, 'maximo': 2});
      ana.accion('listo', {'listo': true});
      ana.accion('iniciar');
      expect(ana.ultimoError!['codigo'], 'faltan_jugadores');
    });

    test('con todos listos (el anfitrión también)', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      mesa.salaCon([ana, beto]);
      beto.accion('listo', {'listo': true});
      ana.accion('iniciar');
      expect(ana.ultimoError!['codigo'], 'no_todos_listos');
      ana.accion('listo', {'listo': true});
      ana.accion('iniciar');
      expect(ana.sala['fase'], 'numeros');
      expect(ana.sala['segundosParaNumeros'], 90);
    });

    test('después de iniciar ya no se cambia el listo ni se sale', () {
      final ana = mesa.entrar('ana');
      mesa.partidaCon([ana, mesa.entrar('beto')]);
      ana.accion('listo', {'listo': false});
      expect(ana.ultimoError!['codigo'], 'fase_incorrecta');
      ana.accion('salir');
      expect(ana.ultimoError!['codigo'], 'fase_incorrecta');
      ana.accion('iniciar');
      expect(ana.ultimoError!['codigo'], 'fase_incorrecta');
    });
  });
}
