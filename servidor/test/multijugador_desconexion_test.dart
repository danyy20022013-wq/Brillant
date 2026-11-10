import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:test/test.dart';

import 'ayuda_multijugador.dart';

void main() {
  late Mesa mesa;

  setUp(() => mesa = Mesa());
  tearDown(() => mesa.cerrar());

  (String, Map<int, ClienteSimulado>) enTurnos(List<String> nombres) {
    final clientes = {for (final n in nombres) mesa.idDe(n): mesa.entrar(n)};
    final lista = clientes.values.toList();
    final codigo = mesa.partidaCon(lista);
    mesa.mandarNumeros(lista);
    return (codigo, clientes);
  }

  Partida partidaDe(String codigo) => mesa.mj.sala(codigo)!.partida!;

  group('en el lobby', () {
    test('quien se cae sale de la sala a los 15 s', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      final codigo = mesa.salaCon([ana, beto]);
      beto.cortar();
      expect(ana.sala.jugador(mesa.idDe('beto'))['conectado'], isFalse);
      mesa.programador.avanzar(const Duration(seconds: 14));
      expect(mesa.mj.sala(codigo)!.miembros.length, 2);
      mesa.programador.avanzar(const Duration(seconds: 1));
      expect(ana.sala.jugadores.length, 1);
      expect(mesa.mj.codigoDeSalaDe(mesa.idDe('beto')), isNull);
    });

    test('si vuelve antes de 15 s sigue en la sala', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      final codigo = mesa.salaCon([ana, beto]);
      beto.accion('listo', {'listo': true});
      beto.cortar();
      mesa.programador.avanzar(const Duration(seconds: 10));
      final beto2 = mesa.entrar('beto');
      expect(beto2.sala['codigo'], codigo);
      expect(beto2.sala.jugador(mesa.idDe('beto'))['listo'], isTrue);
      expect(beto2.sala.jugador(mesa.idDe('beto'))['conectado'], isTrue);
      mesa.programador.avanzar(const Duration(seconds: 30));
      expect(mesa.mj.sala(codigo)!.miembros.length, 2);
    });

    test('si se cae el anfitrión y no vuelve, el siguiente es anfitrión', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      mesa.salaCon([ana, beto]);
      ana.cortar();
      mesa.programador.avanzar(const Duration(seconds: 15));
      expect(beto.sala['anfitrion'], mesa.idDe('beto'));
    });

    test('si todos se caen, la sala se borra', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      final codigo = mesa.salaCon([ana, beto]);
      ana.cortar();
      beto.cortar();
      mesa.programador.avanzar(const Duration(seconds: 15));
      expect(mesa.mj.sala(codigo), isNull);
    });
  });

  group('en la partida', () {
    test('al caerse queda "desconectado" y los demás lo ven', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final beto = clientes[mesa.idDe('beto')]!;
      beto.cortar();
      final sala = clientes[mesa.idDe('ana')]!.sala;
      expect(sala.jugador(mesa.idDe('beto'))['conectado'], isFalse);
      expect(sala.jugador(mesa.idDe('beto'))['estado'], 'jugando');
      expect(partidaDe(codigo).fase, FasePartida.turnos);
    });

    test(
      'vuelve dentro del plazo con su token y recibe el estado completo',
      () {
        final (codigo, clientes) = enTurnos(['ana', 'beto']);
        final p = partidaDe(codigo);
        final id = mesa.idDe('beto');
        clientes[id]!.cortar();
        mesa.programador.avanzar(const Duration(seconds: 59));

        final beto2 = mesa.entrar('beto');
        clientes[id] = beto2;
        expect(beto2.ultimo('autenticado')!['sala'], codigo);
        final sala = beto2.sala;
        expect(sala['codigo'], codigo);
        expect(sala['fase'], 'turnos');
        expect(sala.jugador(id)['conectado'], isTrue);
        expect(sala.jugador(id)['tablero'], isNotNull);
        expect(sala.turno, isNotNull);

        // El plazo de abandono se canceló.
        mesa.programador.avanzar(const Duration(seconds: 30));
        expect(p.jugador(id).estado, EstadoJugador.jugando);
        // Y puede seguir jugando cuando le toque.
        if (p.turnoDe != id) clientes[p.turnoDe]!.accion('saltar');
        expect(p.turnoDe, id);
        beto2.accion('saltar');
        expect(beto2.ultimoError, isNull);
      },
    );

    test('si no vuelve en 60 s, abandonó', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto', 'cami']);
      final p = partidaDe(codigo);
      final id = mesa.idDe('cami');
      clientes[id]!.cortar();
      // Los demás siguen jugando a tiempo mientras tanto.
      mesa.programador.avanzar(const Duration(seconds: 30));
      if (p.turnoDe != id) clientes[p.turnoDe]!.accion('saltar');
      mesa.programador.avanzar(const Duration(seconds: 30));

      expect(p.jugador(id).estado, EstadoJugador.abandono);
      final sala = clientes[mesa.idDe('ana')]!.sala;
      expect(sala.jugador(id)['estado'], 'abandono');
      expect(sala['fase'], 'turnos');
      expect(p.turnoDe, isNot(id));

      // Si vuelve tarde, ve la partida pero ya no juega.
      final cami2 = mesa.entrar('cami');
      expect(cami2.sala.jugador(id)['estado'], 'abandono');
      cami2.accion('saltar');
      expect(cami2.ultimoError!['codigo'], 'ya_no_juegas');
    });

    test('si era su turno, el temporizador sigue corriendo', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final p = partidaDe(codigo);
      final quien = p.turnoDe!;
      mesa.programador.avanzar(const Duration(seconds: 20));
      clientes[quien]!.cortar();
      mesa.programador.avanzar(const Duration(seconds: 40));
      // A los 60 s del turno (no 60 s desde la caída) se le saltó.
      expect(p.turnoDe, isNot(quien));
      expect(p.jugador(quien).saltosPorTiempo, 1);
      expect(p.jugador(quien).activo, isTrue);
    });

    test('si se cae y queda uno solo, ese gana', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final ana = clientes[mesa.idDe('ana')]!;
      clientes[mesa.idDe('beto')]!.cortar();
      // Ana juega a tiempo mientras espera.
      final p = partidaDe(codigo);
      for (var i = 0; i < 6; i++) {
        mesa.programador.avanzar(const Duration(seconds: 10));
        if (p.turnoDe == mesa.idDe('ana')) ana.accion('saltar');
      }
      expect(p.fase, FasePartida.terminada);
      expect(ana.sala.resultado.first['id'], mesa.idDe('ana'));
      expect(ana.sala.resultado.last['estado'], 'abandono');
    });

    test('la caída por latido cuenta igual que una desconexión', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      final beto = clientes[mesa.idDe('beto')]!..responderPings = false;
      mesa.programador.avanzar(const Duration(seconds: 20));
      expect(beto.codigoCierre, CierreWs.sinLatido);
      final sala = clientes[mesa.idDe('ana')]!.sala;
      expect(sala.jugador(mesa.idDe('beto'))['conectado'], isFalse);
      expect(mesa.mj.sala(codigo), isNotNull);
    });

    test('sin nadie conectado 5 minutos, la partida se cierra', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      for (final c in clientes.values) {
        c.cortar();
      }
      mesa.programador.avanzar(const Duration(minutes: 4, seconds: 59));
      expect(mesa.mj.sala(codigo), isNotNull);
      mesa.programador.avanzar(const Duration(seconds: 1));
      expect(mesa.mj.sala(codigo), isNull);
      expect(mesa.mj.codigoDeSalaDe(mesa.idDe('ana')), isNull);

      // Al volver, la sala ya no existe.
      final ana = mesa.entrar('ana', sala: codigo);
      expect(ana.ultimo('sala_no_existe')!['codigo'], codigo);
    });

    test('si alguien vuelve antes de 5 minutos, no se cierra', () {
      final (codigo, clientes) = enTurnos(['ana', 'beto']);
      for (final c in clientes.values) {
        c.cortar();
      }
      mesa.programador.avanzar(const Duration(seconds: 30));
      mesa.entrar('ana');
      mesa.programador.avanzar(const Duration(minutes: 10));
      expect(mesa.mj.sala(codigo), isNotNull);
    });

    test('quien se cae durante los números iniciales tiene su plazo', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      final codigo = mesa.partidaCon([ana, beto]);
      beto.cortar();
      mesa.programador.avanzar(const Duration(seconds: 60));
      final p = partidaDe(codigo);
      expect(p.jugador(mesa.idDe('beto')).estado, EstadoJugador.abandono);
      expect(p.fase, FasePartida.terminada);
    });

    test('caído en el lobby al iniciar pasa al plazo de la partida', () {
      final ana = mesa.entrar('ana');
      final beto = mesa.entrar('beto');
      final codigo = mesa.salaCon([ana, beto]);
      ana.accion('listo', {'listo': true});
      beto.accion('listo', {'listo': true});
      beto.cortar();
      ana.accion('iniciar');
      // No sale a los 15 s como en el lobby: tiene 60 s para volver.
      mesa.programador.avanzar(const Duration(seconds: 20));
      expect(mesa.mj.sala(codigo)!.miembros.length, 2);
      final beto2 = mesa.entrar('beto');
      expect(beto2.sala['fase'], 'numeros');
      mesa.programador.avanzar(const Duration(seconds: 60));
      expect(
        partidaDe(codigo).jugador(mesa.idDe('beto')).estado,
        EstadoJugador.jugando,
      );
    });
  });

  test('el plazo de reconexión es configurable', () {
    final corta = Mesa(
      opciones: const OpcionesMultijugador(
        reconexion: Duration(seconds: 20),
        turno: Duration(seconds: 30),
      ),
    );
    addTearDown(corta.cerrar);
    final clientes = {
      for (final n in ['ana', 'beto', 'cami']) corta.idDe(n): corta.entrar(n),
    };
    final codigo = corta.partidaCon(clientes.values.toList());
    corta.mandarNumeros(clientes.values.toList());
    final p = corta.mj.sala(codigo)!.partida!;
    expect(clientes.values.first.sala.turno!['segundosRestantes'], 30);
    final id = corta.idDe('cami');
    clientes[id]!.cortar();
    corta.programador.avanzar(const Duration(seconds: 20));
    expect(p.jugador(id).estado, EstadoJugador.abandono);
  });
}
