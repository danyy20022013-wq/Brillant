/// Prueba de integración: levanta el servidor REAL (dart run
/// bin/servidor.dart) en un puerto libre, con una base de datos temporal y
/// una clave generada solo para esta prueba, y conecta dos clientes de la
/// app por WebSocket.
///
/// Es lenta (compila y arranca el servidor), así que solo corre si se pide:
///
///   PowerShell:  $env:BRILLIANT_INTEGRACION='1'; flutter test --tags integracion
///   bash:        BRILLIANT_INTEGRACION=1 flutter test --tags integracion
///
/// Usa el Dart de FLUTTER_ROOT; otro Dart se elige con BRILLIANT_DART
/// (por ejemplo C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe). El
/// servidor necesita Dart 3.11 o superior.
@Tags(['integracion'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/api_auth_repository.dart';
import 'package:juego_brilliant/multijugador/canal_ws.dart';
import 'package:juego_brilliant/multijugador/conexion_multijugador.dart';
import 'package:juego_brilliant/multijugador/multijugador_cubit.dart';
import 'package:juego_brilliant/multijugador/vista_partida_multi.dart';

final _activada = Platform.environment['BRILLIANT_INTEGRACION'] == '1';

String _dart() {
  final elegido = Platform.environment['BRILLIANT_DART'];
  if (elegido != null && elegido.isNotEmpty) return elegido;
  final raiz = Platform.environment['FLUTTER_ROOT'];
  if (raiz != null) {
    final exe = Platform.isWindows ? 'dart.exe' : 'dart';
    final ruta = [raiz, 'bin', 'cache', 'dart-sdk', 'bin', exe].join(
      Platform.pathSeparator,
    );
    if (File(ruta).existsSync()) return ruta;
  }
  return 'dart';
}

/// Clave al azar solo para esta prueba (nunca se guarda ni se muestra).
String _claveDePrueba() {
  final r = Random.secure();
  return base64Url.encode(List<int>.generate(48, (_) => r.nextInt(256)));
}

Future<int> _puertoLibre() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final puerto = s.port;
  await s.close();
  return puerto;
}

Future<void> _esperarQue(
  bool Function() condicion,
  String que, {
  Duration maximo = const Duration(seconds: 20),
}) async {
  final limite = DateTime.now().add(maximo);
  while (!condicion()) {
    if (DateTime.now().isAfter(limite)) {
      throw TimeoutException('No se cumplió: $que');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  Process? servidor;
  Directory? temporal;
  final salida = StringBuffer();

  tearDown(() async {
    servidor?.kill();
    await servidor?.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () => -1,
    );
    servidor = null;
    if (temporal != null && temporal!.existsSync()) {
      // En Windows SQLite suelta el archivo cuando termina el proceso.
      await temporal!.delete(recursive: true);
    }
  });

  test(
    'dos clientes: crear sala, unirse, listos, iniciar y una jugada',
    () async {
      temporal = await Directory.systemTemp.createTemp('brilliant_integ_');
      final puerto = await _puertoLibre();
      final proceso = await Process.start(
        _dart(),
        ['run', 'bin/servidor.dart'],
        workingDirectory: 'servidor',
        environment: {
          'HOST': '127.0.0.1',
          'PUERTO': '$puerto',
          'MODO': 'desarrollo',
          'RUTA_BASE_DATOS':
              '${temporal!.path}${Platform.pathSeparator}prueba.db',
          'JWT_SECRETO': _claveDePrueba(),
          'COSTO_BCRYPT': '4',
        },
      );
      servidor = proceso;
      final listo = Completer<void>();
      proceso.stdout.transform(utf8.decoder).listen((texto) {
        salida.write(texto);
        if (texto.contains('escuchando') && !listo.isCompleted) {
          listo.complete();
        }
      });
      proceso.stderr.transform(utf8.decoder).listen(salida.write);
      unawaited(
        proceso.exitCode.then((codigo) {
          if (!listo.isCompleted) {
            listo.completeError(
              StateError('El servidor terminó ($codigo):\n$salida'),
            );
          }
        }),
      );
      await listo.future.timeout(const Duration(minutes: 3));

      final base = 'http://127.0.0.1:$puerto';
      final sufijo = Random().nextInt(99999);
      final repoAna = ApiAuthRepository(urlBase: base);
      final repoBeto = ApiAuthRepository(urlBase: base);
      await repoAna.registrar(
        nombre: 'ana_$sufijo',
        correo: 'ana$sufijo@correo.com',
        contrasena: 'secreta1',
      );
      await repoBeto.registrar(
        nombre: 'beto_$sufijo',
        correo: 'beto$sufijo@correo.com',
        contrasena: 'secreta1',
      );

      MultijugadorCubit cliente(ApiAuthRepository repo, AccionInicial a) =>
          MultijugadorCubit(
            conexion: ConexionMultijugador(
              url: urlWebSocket(repo.urlBase),
              token: () async => repo.tokenActual,
            ),
            accionInicial: a,
          );

      final ana = cliente(
        repoAna,
        const AccionInicial.crear(mapa: 1, maximo: 2),
      );
      addTearDown(ana.close);
      await ana.conectar();
      await _esperarQue(() => ana.state.sala != null, 'ana crea la sala');
      final codigo = ana.state.sala!.codigo;
      expect(codigo.length, 6);
      expect(ana.state.soyAnfitrion, isTrue);

      final beto = cliente(repoBeto, AccionInicial.unirse(codigo));
      addTearDown(beto.close);
      await beto.conectar();
      await _esperarQue(
        () =>
            ana.state.sala?.jugadores.length == 2 &&
            beto.state.sala?.jugadores.length == 2,
        'beto se une',
      );

      ana.listo(true);
      beto.listo(true);
      await _esperarQue(
        () => ana.state.sala?.sePuedeIniciar ?? false,
        'los dos listos',
      );
      ana.iniciar();
      await _esperarQue(
        () => beto.state.sala?.enNumeros ?? false,
        'empieza la partida',
      );

      ana.enviarNumeros(const [1, 2, 3, 4, 5, 6]);
      beto.enviarNumeros(const [6, 5, 4, 3, 2, 1]);
      await _esperarQue(
        () =>
            (ana.state.sala?.enTurnos ?? false) &&
            (beto.state.sala?.enTurnos ?? false),
        'empiezan los turnos',
      );

      // Juega turnos hasta que haya una colocación (si los dados no dan
      // jugada, se salta). Siempre con los dados que tiró el servidor.
      var colocada = false;
      for (var i = 0; i < 30 && !colocada; i++) {
        final sala = ana.state.sala!;
        final turno = sala.turno!;
        final quien = turno.jugador == ana.state.miId ? ana : beto;
        final juego = juegoDesdeTablero(
          sala.nivel,
          sala.jugador(turno.jugador)!.tablero!,
        )!;
        (int, int, int)? jugada;
        for (final dadoAncla in [0, 1]) {
          final ancla = dadoAncla == 0 ? turno.dado1 : turno.dado2;
          final valor = dadoAncla == 0 ? turno.dado2 : turno.dado1;
          final posibles = juego.jugadasPosibles(
            ancla: ancla,
            aColocar: valor,
          );
          if (posibles.isNotEmpty) {
            jugada = (dadoAncla, posibles.first.$1, posibles.first.$2);
            break;
          }
        }
        if (jugada == null) {
          quien.saltar();
        } else {
          quien.colocar(jugada.$1, jugada.$2, jugada.$3);
          colocada = true;
        }
        await _esperarQue(
          () =>
              ana.state.sala?.turno?.numero != turno.numero &&
              beto.state.sala?.turno?.numero != turno.numero,
          'el servidor confirma el turno ${turno.numero}',
        );
        if (colocada) {
          // Los dos ven la misma jugada confirmada por el servidor.
          for (final c in [ana, beto]) {
            final mov = c.state.sala!.ultimoMovimiento!;
            expect(mov.tipo, 'colocacion');
            expect(mov.jugador, turno.jugador);
            final tablero = c.state.sala!.jugador(turno.jugador)!.tablero!;
            expect(tablero[jugada!.$2][jugada.$3], isNotNull);
          }
        }
      }
      expect(colocada, isTrue);
      expect(ana.state.conexion, EstadoConexion.conectado);
      expect(beto.state.conexion, EstadoConexion.conectado);
    },
    skip: _activada
        ? false
        : 'Lenta: corre con BRILLIANT_INTEGRACION=1 y --tags integracion',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
