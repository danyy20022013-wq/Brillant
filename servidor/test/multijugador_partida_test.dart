import 'package:reglas_brilliant/reglas_brilliant.dart';
import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:test/test.dart';

import 'ayuda_multijugador.dart';

void main() {
  late Mesa mesa;

  setUp(() => mesa = Mesa());
  tearDown(() => mesa.cerrar());

  /// Partida de [nombres] ya en la fase de turnos.
  (String, Map<int, ClienteSimulado>) enTurnos(
    List<String> nombres, {
    int mapa = 1,
  }) {
    final clientes = {for (final n in nombres) mesa.idDe(n): mesa.entrar(n)};
    final lista = clientes.values.toList();
    final codigo = mesa.partidaCon(lista, mapa: mapa);
    mesa.mandarNumeros(lista, nivel: nivelPorNumero(mapa));
    return (codigo, clientes);
  }

  Partida partidaDe(String codigo) => mesa.mj.sala(codigo)!.partida!;

  group('números iniciales', () {
    test('cada jugador manda los suyos y el servidor los valida', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      final codigo = mesa.partidaCon([ana, beto]);

      ana.accion('numeros_iniciales', {
        'numeros': [1, 1, 2, 3, 4, 5],
      });
      expect(ana.ultimoError!['codigo'], 'numeros_invalidos');
      ana.accion('numeros_iniciales', {'numeros': 'hola'});
      expect(ana.ultimoError!['codigo'], 'numeros_invalidos');
      ana.accion('numeros_iniciales', {
        'numeros': [1, 2, 3, 4, 5, 6],
      });
      expect(ana.sala.jugador(mesa.idDe('ana'))['numerosEnviados'], isTrue);
      // Los números no se ven hasta que empiezan los turnos.
      expect(beto.sala.jugador(mesa.idDe('ana'))['tablero'], isNull);
      ana.accion('numeros_iniciales', {
        'numeros': [6, 5, 4, 3, 2, 1],
      });
      expect(ana.ultimoError!['codigo'], 'numeros_ya_enviados');

      beto.accion('numeros_iniciales', {
        'numeros': [6, 5, 4, 3, 2, 1],
      });
      expect(beto.sala['fase'], 'turnos');
      expect(partidaDe(codigo).jugador(mesa.idDe('beto')).numeros, [
        6,
        5,
        4,
        3,
        2,
        1,
      ]);
    });

    test('en el mapa 4 respeta los naranjas', () {
      final ana = mesa.entrar('ana');
      mesa.partidaCon([ana, mesa.entrar('beto')], mapa: 4);
      ana.accion('numeros_iniciales', {
        'numeros': [1, 2, 3, 4, 5, 6],
      });
      expect(ana.ultimoError!['codigo'], 'numeros_invalidos');
      ana.olvidar();
      ana.accion('numeros_iniciales', {
        'numeros': [4, 5, 6, 1, 2, 3],
      });
      expect(ana.ultimoError, isNull);
      expect(ana.sala.jugador(mesa.idDe('ana'))['numerosEnviados'], isTrue);
    });

    test('a los 90 s se asignan números válidos al azar a quien falte', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      final codigo = mesa.partidaCon([ana, beto], mapa: 4);
      ana.accion('numeros_iniciales', {
        'numeros': [4, 5, 6, 1, 2, 3],
      });

      mesa.programador.avanzar(const Duration(seconds: 89));
      expect(ana.sala['fase'], 'numeros');
      mesa.programador.avanzar(const Duration(seconds: 1));

      expect(ana.sala['fase'], 'turnos');
      final asignados = partidaDe(codigo).jugador(mesa.idDe('beto')).numeros!;
      expect(numerosInicialesValidos(nivel4, asignados), isTrue);
      expect(partidaDe(codigo).jugador(mesa.idDe('ana')).numeros, [
        4,
        5,
        6,
        1,
        2,
        3,
      ]);
    });
  });

  group('turnos', () {
    test('orden sorteado, dados del servidor y estado completo', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto', 'cami']);
      final sala = clientes.values.first.sala;

      expect((sala['orden']! as List).toSet(), clientes.keys.toSet());
      expect(sala.turnoDe, (sala['orden']! as List).first);
      expect(sala.turno!['numero'], 1);
      expect(sala.dados.every((d) => d >= 1 && d <= 6), isTrue);
      expect(sala.turno!['segundosRestantes'], 60);
      expect(sala['ordenZonas'], hasLength(nivel1.estructura.zonas.length));
      for (final j in sala.jugadores) {
        expect(j['estado'], 'jugando');
        expect(j['tablero'], hasLength(7));
        expect(j['puntaje'], 0);
        expect(j['conectado'], isTrue);
      }
      final p = partidaDe(codigo);
      expect(sala.dados, [p.dado1, p.dado2]);
    });

    test('una jugada válida coloca, pasa el turno y todos lo ven', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final p = partidaDe(codigo);
      final primero = p.turnoDe!;
      final turnoAntes = p.numeroTurno;

      // Busca una tirada con jugada (si no hay, salta y prueba otra).
      while (!jugarTurno(mesa, codigo, clientes)) {}
      final sala = clientes.values.first.sala;
      final mov = sala['ultimoMovimiento']! as Map<String, Object?>;
      expect(mov['tipo'], 'colocacion');
      final quien = mov['jugador']! as int;
      final tablero =
          (sala.jugador(quien)['tablero']! as List)[mov['fila']! as int]
              as List;
      expect(tablero[mov['columna']! as int], mov['colocado']);
      expect(p.numeroTurno, greaterThan(turnoAntes));
      expect(primero, isNotNull);
    });

    test('jugadas inválidas se rechazan', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final p = partidaDe(codigo);
      final c = clientes[p.turnoDe]!;
      final turno = p.numeroTurno;

      for (final datos in [
        {'dadoAncla': 2, 'fila': 0, 'columna': 0},
        {'dadoAncla': 0, 'fila': 'a', 'columna': 0},
        {'dadoAncla': 0},
        // Casilla con estrella (ocupada).
        {'dadoAncla': 0, 'fila': 0, 'columna': 2},
        // Fuera del tablero.
        {'dadoAncla': 0, 'fila': 9, 'columna': 9},
      ]) {
        c.accion('colocar', datos);
        expect(c.ultimoError!['codigo'], 'jugada_invalida', reason: '$datos');
      }
      expect(p.numeroTurno, turno);
    });

    test('fuera de turno se rechaza', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final p = partidaDe(codigo);
      final otro = clientes.entries.firstWhere((e) => e.key != p.turnoDe);
      otro.value.accion('saltar');
      expect(otro.value.ultimoError!['codigo'], 'fuera_de_turno');
      otro.value.accion('colocar', {'dadoAncla': 0, 'fila': 0, 'columna': 1});
      expect(otro.value.ultimoError!['codigo'], 'fuera_de_turno');
      expect(p.numeroTurno, 1);
    });

    test('una acción repetida o vieja se ignora', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final p = partidaDe(codigo);
      final c = clientes[p.turnoDe]!;
      c.siguienteId = 50;
      c.accion('saltar'); // id 50
      expect(p.numeroTurno, 2);

      // El mismo id otra vez (reintento) o uno viejo: no hace nada ni
      // responde.
      c.olvidar();
      c.siguienteId = 50;
      c.accion('rendirse');
      c.siguienteId = 10;
      c.accion('rendirse');
      expect(c.recibidos, isEmpty);
      expect(p.jugador(mesa.idDe('ana')).activo, isTrue);
      expect(p.jugador(mesa.idDe('beto')).activo, isTrue);
    });

    test('el cliente nunca elige los dados', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final p = partidaDe(codigo);
      final id = p.turnoDe!;
      final c = clientes[id]!;
      final dados = (p.dado1, p.dado2);

      // No existe un mensaje para tirar o fijar los dados.
      for (final tipo in ['tirar_dados', 'fijar_dados', 'dados']) {
        c.accion(tipo, {
          'dados': [6, 6],
        });
        expect(c.ultimoError!['codigo'], 'tipo_desconocido');
      }
      // Los campos de dados en una jugada se ignoran: se usan los del
      // servidor.
      c.accion('colocar', {
        'dadoAncla': 0,
        'fila': 0,
        'columna': 1,
        'dado1': 6,
        'dado2': 6,
        'dados': [6, 6],
      });
      if (c.ultimoError == null) {
        // Con el dado 1 de ancla se coloca el valor del dado 2 del servidor.
        expect(p.jugador(id).tablero!.tablero[0][1], dados.$2);
      } else {
        expect(c.ultimoError!['codigo'], 'jugada_invalida');
        expect((p.dado1, p.dado2), dados);
      }
    });

    test('saltar el turno', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final p = partidaDe(codigo);
      final primero = p.turnoDe!;
      clientes[primero]!.accion('saltar');
      expect(p.turnoDe, isNot(primero));
      expect(p.numeroTurno, 2);
      final mov =
          clientes[primero]!.sala['ultimoMovimiento']! as Map<String, Object?>;
      expect(mov, {'tipo': 'salto', 'jugador': primero, 'turno': 1});
    });
  });

  group('temporizador de turno', () {
    test('a los 60 s salta el turno', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final p = partidaDe(codigo);
      final primero = p.turnoDe!;
      mesa.programador.avanzar(const Duration(seconds: 59));
      expect(p.turnoDe, primero);
      expect(clientes[primero]!.sala.turno!['segundosRestantes'], 60);
      mesa.programador.avanzar(const Duration(seconds: 1));
      expect(p.turnoDe, isNot(primero));
      final mov =
          clientes[primero]!.sala['ultimoMovimiento']! as Map<String, Object?>;
      expect(mov['tipo'], 'tiempo_agotado');
      expect(clientes[primero]!.sala.jugador(primero)['saltosPorTiempo'], 1);
    });

    test('jugar a tiempo reinicia el reloj del turno', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final p = partidaDe(codigo);
      mesa.programador.avanzar(const Duration(seconds: 50));
      clientes[p.turnoDe]!.accion('saltar');
      final segundo = p.turnoDe!;
      mesa.programador.avanzar(const Duration(seconds: 50));
      expect(p.turnoDe, segundo);
      mesa.programador.avanzar(const Duration(seconds: 10));
      expect(p.turnoDe, isNot(segundo));
    });

    test('tres saltos seguidos por tiempo cuentan como abandono', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto', 'cami']);
      final p = partidaDe(codigo);
      final dormido = p.orden.first;
      // El dormido nunca juega; los demás saltan a tiempo.
      for (var vuelta = 0; vuelta < 3; vuelta++) {
        expect(p.turnoDe, dormido);
        mesa.programador.avanzar(const Duration(seconds: 60));
        for (var i = 0; i < 2; i++) {
          clientes[p.turnoDe]!.accion('saltar');
        }
      }
      expect(p.jugador(dormido).estado, EstadoJugador.abandono);
      expect(p.turnoDe, isNot(dormido));
      final sala = clientes[dormido]!.sala;
      expect(sala.jugador(dormido)['estado'], 'abandono');
      expect(sala['fase'], 'turnos'); // quedan 2
    });

    test('una jugada a tiempo reinicia la cuenta de saltos', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final p = partidaDe(codigo);
      final j = p.orden.first;
      final otro = p.orden.last;
      mesa.programador.avanzar(const Duration(seconds: 60)); // 1
      clientes[otro]!.accion('saltar');
      mesa.programador.avanzar(const Duration(seconds: 60)); // 2
      clientes[otro]!.accion('saltar');
      clientes[j]!.accion('saltar'); // a tiempo: reinicia
      expect(p.jugador(j).saltosPorTiempo, 0);
      clientes[otro]!.accion('saltar');
      mesa.programador.avanzar(const Duration(seconds: 60));
      expect(p.jugador(j).activo, isTrue);
    });

    test('si se abandona por tiempo y queda uno, termina', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final p = partidaDe(codigo);
      final dormido = p.orden.first;
      final despierto = p.orden.last;
      for (var vuelta = 0; vuelta < 3; vuelta++) {
        mesa.programador.avanzar(const Duration(seconds: 60));
        if (vuelta < 2) clientes[despierto]!.accion('saltar');
      }
      final sala = clientes[despierto]!.sala;
      expect(sala['fase'], 'terminada');
      expect(sala.resultado.first['id'], despierto);
      expect(sala.resultado.first['posicion'], 1);
      expect(sala.resultado.last['id'], dormido);
      expect(sala.resultado.last['estado'], 'abandono');
      expect(sala['turno'], isNull);
      expect(mesa.programador.pendientes, greaterThan(0)); // solo latidos
    });
  });

  group('rendirse', () {
    test('en su turno: queda último y el turno pasa al siguiente', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto', 'cami']);
      final p = partidaDe(codigo);
      final quien = p.turnoDe!;
      final siguiente = p.orden[1];
      clientes[quien]!.accion('rendirse');

      expect(p.jugador(quien).estado, EstadoJugador.rendido);
      expect(p.turnoDe, siguiente);
      final sala = clientes[siguiente]!.sala;
      expect(sala.jugador(quien)['estado'], 'rendido');
      expect(sala['fase'], 'turnos');
      // Su tablero queda congelado: ya no le vuelve a tocar.
      for (var i = 0; i < 6; i++) {
        expect(p.turnoDe, isNot(quien));
        clientes[p.turnoDe]!.accion('saltar');
      }
    });

    test('en turno ajeno: el turno no cambia', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto', 'cami']);
      final p = partidaDe(codigo);
      final turno = p.turnoDe!;
      final quien = p.orden[1];
      clientes[quien]!.accion('rendirse');
      expect(p.turnoDe, turno);
      expect(p.numeroTurno, 1);
      clientes[turno]!.accion('saltar');
      expect(p.turnoDe, p.orden[2]); // se salta al rendido
    });

    test('quien se rinde no puede seguir jugando', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto', 'cami']);
      final p = partidaDe(codigo);
      final quien = p.orden[1];
      clientes[quien]!.accion('rendirse');
      clientes[quien]!.accion('rendirse');
      expect(clientes[quien]!.ultimoError!['codigo'], 'ya_no_juegas');
    });

    test('hasta que queda uno: gana y termina', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto', 'cami', 'dani']);
      final p = partidaDe(codigo);
      final orden = [...p.orden];
      clientes[orden[2]]!.accion('rendirse');
      clientes[orden[0]]!.accion('rendirse');
      expect(p.fase, FasePartida.turnos);
      clientes[orden[3]]!.accion('rendirse');

      final sala = clientes[orden[1]]!.sala;
      expect(sala['fase'], 'terminada');
      expect(sala.resultado.map((r) => (r['id'], r['posicion'])), [
        (orden[1], 1),
        (orden[3], 2), // el último en rendirse queda mejor
        (orden[0], 3),
        (orden[2], 4),
      ]);
      // Ya no hay temporizador de turno.
      expect(sala['turno'], isNull);
    });

    test('el que se rinde queda último aunque tenga más puntos', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto', 'cami']);
      final p = partidaDe(codigo);
      final rico = p.orden.first;
      // Le damos puntos a mano: llena primero una zona.
      p.ordenZonas[0].add(rico);
      clientes[rico]!.accion('rendirse');
      final resto = p.orden.where((id) => id != rico).toList();
      clientes[resto.first]!.accion('rendirse');
      final resultado = clientes[resto.last]!.sala.resultado;
      expect(resultado.last['id'], rico);
      expect(resultado.last['puntaje'], greaterThan(0));
      expect(resultado.first['puntaje'], 0);
    });

    test('rendirse durante los números iniciales', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      final cami = mesa.entrar('cami');
      final codigo = mesa.partidaCon([ana, beto, cami]);
      mesa.mandarNumeros([ana, beto]);
      cami.accion('rendirse');
      // Los que quedan ya mandaron: empiezan los turnos sin cami.
      final p = partidaDe(codigo);
      expect(p.fase, FasePartida.turnos);
      expect(p.orden, isNot(contains(mesa.idDe('cami'))));
      beto.accion('rendirse');
      expect(p.fase, FasePartida.terminada);
      expect(ana.sala.resultado.first['id'], mesa.idDe('ana'));
    });

    test('después de rendirse puede salir y entrar a otra sala', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto', 'cami']);
      final ana = clientes[mesa.idDe('ana')]!;
      ana.accion('rendirse');
      ana.accion('crear_sala', {'mapa': 2, 'maximo': 2});
      expect(ana.ultimoError, isNull);
      expect(ana.sala['codigo'], isNot(codigo));
      // En la partida sigue figurando, como rendida y fuera de la sala.
      final vista = clientes[mesa.idDe('beto')]!.sala;
      expect(vista.jugador(mesa.idDe('ana'))['estado'], 'rendido');
      expect(vista.jugador(mesa.idDe('ana'))['enSala'], isFalse);
    });
  });

  group('partida completa', () {
    test('de 2 jugadores, hasta llenar los tableros', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final turnos = jugarHastaTerminar(mesa, codigo, clientes);
      final p = partidaDe(codigo);

      expect(p.fase, FasePartida.terminada);
      expect(turnos, greaterThan(40));
      for (final j in p.jugadores) {
        expect(j.tablero!.estaLleno, isTrue);
      }
      final resultado = clientes.values.first.sala.resultado;
      expect(resultado.length, 2);
      for (final r in resultado) {
        expect(r['puntaje'], p.puntajeDe(r['id']! as int));
        expect(r['estado'], 'jugando');
      }
      expect(
        resultado.first['puntaje']! as int,
        greaterThanOrEqualTo(resultado.last['puntaje']! as int),
      );
      // Cada zona la llenaron los dos.
      for (final orden in p.ordenZonas) {
        expect(orden.toSet(), clientes.keys.toSet());
      }
    });

    test('de 4 jugadores en el mapa 4', () {
      final (codigo, clientes) = enTurnos([
        'ana',
        'beto',
        'cami',
        'dani',
      ], mapa: 4);
      jugarHastaTerminar(mesa, codigo, clientes);
      final p = partidaDe(codigo);
      final resultado = clientes.values.last.sala.resultado;
      expect(resultado.length, 4);
      expect(resultado.first['posicion'], 1);
      // Posiciones con empates: 1, 1, 3... nunca saltan hacia atrás.
      for (var i = 1; i < resultado.length; i++) {
        final antes = resultado[i - 1];
        final ahora = resultado[i];
        if (ahora['puntaje'] == antes['puntaje']) {
          expect(ahora['posicion'], antes['posicion']);
        } else {
          expect(ahora['posicion'], i + 1);
        }
      }
      // El 4.º en llenar una zona ya no puntúa.
      for (var z = 0; z < p.ordenZonas.length; z++) {
        expect(p.ordenZonas[z].length, 4);
        expect(
          puntosEnZona(nivel4.estructura, p.ordenZonas, p.ordenZonas[z][3], z),
          0,
        );
      }
    });

    test('al terminar, todos pueden irse y la sala se borra', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      jugarHastaTerminar(mesa, codigo, clientes);
      for (final c in clientes.values) {
        c.accion('salir');
        expect(c.ultimo('saliste'), isNotNull);
      }
      expect(mesa.mj.sala(codigo), isNull);
    });

    test('una jugada después de terminar se rechaza', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      jugarHastaTerminar(mesa, codigo, clientes);
      final c = clientes.values.first;
      c.accion('saltar');
      expect(c.ultimoError!['codigo'], 'partida_terminada');
    });
  });
}
