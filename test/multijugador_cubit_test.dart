import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/multijugador/canal_ws.dart';
import 'package:juego_brilliant/multijugador/conexion_multijugador.dart';
import 'package:juego_brilliant/multijugador/multijugador_cubit.dart';

import 'ayuda_multijugador.dart';

void main() {
  late ServidorFalso servidor;

  setUp(() => servidor = ServidorFalso());

  MultijugadorCubit nuevo({
    AccionInicial? accion = const AccionInicial.crear(mapa: 2, maximo: 3),
    String? token = 'token-de-prueba',
    int maximoIntentos = 3,
    Duration silencioMaximo = const Duration(hours: 1),
    RelojFalso? reloj,
  }) {
    final cubit = MultijugadorCubit(
      conexion: conexionDePrueba(
        servidor,
        token: token,
        maximoIntentos: maximoIntentos,
        silencioMaximo: silencioMaximo,
      ),
      accionInicial: accion,
      reloj: reloj?.call,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('conexión', () {
    test('la URL del WebSocket sale de la del servidor, sin token', () {
      expect(
        urlWebSocket(Uri.parse('http://localhost:8080')).toString(),
        'ws://localhost:8080/ws',
      );
      expect(
        urlWebSocket(Uri.parse('https://brilliant.ejemplo.com/')).toString(),
        'wss://brilliant.ejemplo.com/ws',
      );
    });

    test('el token va en el primer mensaje, nunca en la URL', () async {
      final cubit = nuevo();
      await cubit.conectar();
      await pasar();

      expect(servidor.urls.single, urlDePrueba);
      expect(servidor.urls.single.query, isEmpty);
      final primero = servidor.actual.enviados.first;
      expect(primero, {'tipo': 'autenticar', 'token': 'token-de-prueba'});
      expect(cubit.state.conexion, EstadoConexion.conectando);
    });

    test('contesta los ping con pong', () async {
      final cubit = nuevo();
      await cubit.conectar();
      await pasar();
      servidor.actual.recibir({'tipo': 'ping'});
      await pasar();
      expect(servidor.actual.de('pong'), hasLength(1));
    });

    test('al autenticarse queda conectada y manda la acción inicial', () async {
      final cubit = nuevo();
      await cubit.conectar();
      await pasar();
      servidor.actual.autenticado(7, 'ana');
      await pasar();

      expect(cubit.state.conexion, EstadoConexion.conectado);
      expect(cubit.state.miId, 7);
      expect(servidor.actual.ultimo('crear_sala'), {
        'tipo': 'crear_sala',
        'id': 1,
        'mapa': 2,
        'maximo': 3,
      });
    });

    test('sin token no intenta y avisa que la sesión no es válida', () async {
      final cubit = nuevo(token: null);
      await cubit.conectar();
      await pasar();
      expect(servidor.intentos, 0);
      expect(cubit.state.fin, isTrue);
      expect(cubit.state.motivoFin, MensajesMultijugador.sesionInvalida);
    });

    test('esperas crecientes 1, 2, 4, 8 y tope de 15 s', () {
      expect(esperasPorDefecto.map((d) => d.inSeconds), [1, 2, 4, 8, 15]);
    });

    test(
      'servidor apagado: reintenta y al agotar los intentos avisa',
      () async {
        servidor.disponible = false;
        final cubit = nuevo(maximoIntentos: 3);
        final estados = <EstadoConexion>[];
        final sub = cubit.stream.listen((e) => estados.add(e.conexion));
        await cubit.conectar();
        for (var i = 0; i < 6; i++) {
          await pasar();
        }
        await sub.cancel();

        expect(servidor.intentos, 4); // el primero + 3 reintentos
        expect(cubit.state.conexion, EstadoConexion.cerrado);
        expect(estados, contains(EstadoConexion.caido));
        expect(cubit.state.fin, isTrue);
        expect(
          cubit.state.motivoFin,
          MensajesMultijugador.servidorNoDisponible,
        );
      },
    );
  });

  group('crear y unirse', () {
    test('unirse manda el código', () async {
      final cubit = nuevo(accion: const AccionInicial.unirse('ABC234'));
      await cubit.conectar();
      await pasar();
      servidor.actual.autenticado(7, 'ana');
      await pasar();
      expect(servidor.actual.ultimo('unirse'), {
        'tipo': 'unirse',
        'id': 1,
        'codigo': 'ABC234',
      });
    });

    test('la sala refleja exactamente lo que manda el servidor', () async {
      final cubit = nuevo();
      await cubit.conectar();
      await pasar();
      servidor.actual
        ..autenticado(7, 'ana')
        ..estado(
          lobbyJson(
            maximo: 3,
            jugadores: [
              jugadorJson(7, 'ana', anfitrion: true),
              jugadorJson(8, 'beto', listo: true, conectado: false),
            ],
          ),
        );
      await pasar();

      final sala = cubit.state.sala!;
      expect(sala.codigo, 'K7M2QX');
      expect(sala.enLobby, isTrue);
      expect(cubit.state.soyAnfitrion, isTrue);
      expect(sala.jugador(8)!.listo, isTrue);
      expect(sala.jugador(8)!.conectado, isFalse);
      expect(sala.sePuedeIniciar, isFalse);
    });

    for (final (codigo, mensaje) in [
      ('sala_inexistente', 'No existe una sala con ese código'),
      ('sala_llena', 'La sala está llena'),
      ('sala_iniciada', 'La partida de esa sala ya empezó'),
    ]) {
      test(
        'si falla unirse ($codigo) se vuelve al menú con el aviso',
        () async {
          final cubit = nuevo(accion: const AccionInicial.unirse('ZZZZZZ'));
          await cubit.conectar();
          await pasar();
          servidor.actual
            ..autenticado(7, 'ana')
            ..error(codigo, mensaje, id: 1);
          await pasar();
          expect(cubit.state.fin, isTrue);
          expect(cubit.state.motivoFin, mensaje);
          expect(servidor.actual.cerradoPorLaApp, isTrue);
        },
      );
    }

    test('si el servidor ya me tiene en una sala, la restaura', () async {
      final cubit = nuevo();
      await cubit.conectar();
      await pasar();
      servidor.actual
        ..autenticado(7, 'ana', sala: 'K7M2QX', ultimaAccion: 12)
        ..estado(
          lobbyJson(jugadores: [jugadorJson(7, 'ana', anfitrion: true)]),
        );
      await pasar();
      expect(servidor.actual.de('crear_sala'), isEmpty);
      expect(cubit.state.sala!.codigo, 'K7M2QX');
      // Y las acciones siguen desde el último id del servidor.
      cubit.listo(true);
      expect(servidor.actual.ultimo('listo')!['id'], 13);
    });
  });

  group('acciones', () {
    Future<MultijugadorCubit> conectado() async {
      final cubit = nuevo();
      await cubit.conectar();
      await pasar();
      servidor.actual
        ..autenticado(7, 'ana')
        ..estado(
          partidaJson(
            jugadores: [
              jugadorJson(
                7,
                'ana',
                estado: 'jugando',
                tablero: tableroInicial(),
              ),
              jugadorJson(
                8,
                'beto',
                estado: 'jugando',
                tablero: tableroInicial(),
              ),
            ],
          ),
        );
      await pasar();
      return cubit;
    }

    test(
      'colocar manda solo el dado ancla y la casilla, nunca dados',
      () async {
        final cubit = await conectado();
        cubit.colocar(0, 0, 1);
        final m = servidor.actual.ultimo('colocar')!;
        expect(m.keys.toSet(), {'tipo', 'id', 'dadoAncla', 'fila', 'columna'});
        expect(m['dadoAncla'], 0);
      },
    );

    test('los ids crecen en cada acción', () async {
      final cubit = await conectado();
      cubit
        ..saltar()
        ..rendirse();
      expect(servidor.actual.ultimo('saltar')!['id'], 2);
      expect(servidor.actual.ultimo('rendirse')!['id'], 3);
    });

    test('un error del servidor se muestra y la sala sigue igual', () async {
      final cubit = await conectado();
      final antes = cubit.state.sala;
      servidor.actual.error('fuera_de_turno', 'No es tu turno', id: 2);
      await pasar();
      expect(cubit.state.error, 'No es tu turno');
      expect(cubit.state.sala, antes);
      expect(cubit.state.fin, isFalse);
    });

    test('sin conexión no manda y avisa', () async {
      final cubit = await conectado();
      servidor.disponible = false;
      servidor.actual.cortar();
      await pasar();
      cubit.saltar();
      expect(cubit.state.error, mensajeSinConexionAccion);
    });

    test('salir: al confirmar el servidor, termina sin aviso', () async {
      final cubit = await conectado();
      cubit.salir();
      expect(servidor.actual.ultimo('salir'), isNotNull);
      servidor.actual.recibir({'tipo': 'saliste', 'codigo': 'K7M2QX'});
      await pasar();
      expect(cubit.state.fin, isTrue);
      expect(cubit.state.motivoFin, isNull);
    });
  });

  group('reconexión', () {
    test(
      'si se corta, reconecta pidiendo la misma sala y la restaura',
      () async {
        final cubit = nuevo();
        await cubit.conectar();
        await pasar();
        servidor.actual
          ..autenticado(7, 'ana')
          ..estado(
            lobbyJson(jugadores: [jugadorJson(7, 'ana', anfitrion: true)]),
          );
        await pasar();
        final primero = servidor.actual;

        primero.cortar(codigo: 1006);
        await pasar();
        expect(servidor.canales, hasLength(2));
        final segundo = servidor.actual;
        expect(segundo.enviados.first, {
          'tipo': 'autenticar',
          'token': 'token-de-prueba',
          'sala': 'K7M2QX',
        });
        expect(cubit.state.conexion, EstadoConexion.reconectando);

        segundo
          ..autenticado(7, 'ana', sala: 'K7M2QX', ultimaAccion: 1)
          ..estado(
            lobbyJson(
              jugadores: [jugadorJson(7, 'ana', anfitrion: true, listo: true)],
            ),
          );
        await pasar();
        expect(cubit.state.conexion, EstadoConexion.conectado);
        expect(cubit.state.sala!.jugador(7)!.listo, isTrue);
        // No vuelve a crear la sala.
        expect(segundo.de('crear_sala'), isEmpty);
      },
    );

    test('si la sala ya no existe al volver, avisa y termina', () async {
      final cubit = nuevo();
      await cubit.conectar();
      await pasar();
      servidor.actual
        ..autenticado(7, 'ana')
        ..estado(
          lobbyJson(jugadores: [jugadorJson(7, 'ana', anfitrion: true)]),
        );
      await pasar();
      servidor.actual.cortar();
      await pasar();
      servidor.actual
        ..autenticado(7, 'ana')
        ..recibir({'tipo': 'sala_no_existe', 'codigo': 'K7M2QX'});
      await pasar();
      expect(cubit.state.fin, isTrue);
      expect(cubit.state.motivoFin, MensajesMultijugador.salaInexistente);
    });

    test('sesión abierta en otro lugar: avisa y no reconecta', () async {
      final cubit = nuevo();
      await cubit.conectar();
      await pasar();
      servidor.actual
        ..autenticado(7, 'ana')
        ..recibir({'tipo': 'sesion_reemplazada', 'mensaje': '…'})
        ..cortar(codigo: 4002, motivo: 'Sesión abierta en otra conexión');
      await pasar();
      expect(servidor.canales, hasLength(1));
      expect(cubit.state.motivoFin, MensajesMultijugador.sesionReemplazada);
    });

    test('token rechazado (4001): sesión no válida, sin reintentar', () async {
      final cubit = nuevo();
      await cubit.conectar();
      await pasar();
      servidor.actual.cortar(codigo: 4001);
      await pasar();
      expect(servidor.canales, hasLength(1));
      expect(cubit.state.motivoFin, MensajesMultijugador.sesionInvalida);
    });

    test('se corta y no vuelve: aviso de sin conexión', () async {
      final cubit = nuevo(maximoIntentos: 2);
      await cubit.conectar();
      await pasar();
      servidor.actual
        ..autenticado(7, 'ana')
        ..estado(
          lobbyJson(jugadores: [jugadorJson(7, 'ana', anfitrion: true)]),
        );
      await pasar();
      servidor.disponible = false;
      servidor.actual.cortar();
      for (var i = 0; i < 5; i++) {
        await pasar();
      }
      expect(cubit.state.motivoFin, MensajesMultijugador.sinConexion);
    });

    test('mucho silencio del servidor cuenta como caída', () async {
      final cubit = nuevo(silencioMaximo: const Duration(milliseconds: 20));
      await cubit.conectar();
      await pasar();
      servidor.actual.autenticado(7, 'ana');
      await pasar();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await pasar();
      expect(servidor.canales.length, greaterThan(1));
      expect(servidor.canales.first.cerradoPorLaApp, isTrue);
    });
  });

  test('cuenta desde cuándo está desconectado cada rival', () async {
    final reloj = RelojFalso();
    final cubit = nuevo(reloj: reloj);
    await cubit.conectar();
    await pasar();
    final c = servidor.actual..autenticado(7, 'ana');
    Map<String, Object?> con(bool conectado) => partidaJson(
      jugadores: [
        jugadorJson(7, 'ana', estado: 'jugando', tablero: tableroInicial()),
        jugadorJson(
          8,
          'beto',
          estado: 'jugando',
          conectado: conectado,
          tablero: tableroInicial(),
        ),
      ],
    );
    c.estado(con(false));
    await pasar();
    final desde = cubit.state.desconectadosDesde[8];
    expect(desde, reloj.ahora);

    // Otro estado con beto todavía caído: no reinicia la cuenta.
    reloj.avanzar(const Duration(seconds: 10));
    c.estado(con(false));
    await pasar();
    expect(cubit.state.desconectadosDesde[8], desde);

    c.estado(con(true));
    await pasar();
    expect(cubit.state.desconectadosDesde, isEmpty);
  });
}
