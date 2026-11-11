import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/auth_repository.dart';
import 'package:juego_brilliant/buscar_partida_screen.dart';
import 'package:juego_brilliant/multijugador/multijugador_cubit.dart';
import 'package:juego_brilliant/multijugador/vista_lobby.dart';
import 'package:juego_brilliant/multijugador/vista_partida_multi.dart';

import 'ayuda_multijugador.dart';

const _pantallas = [Size(320, 568), Size(360, 640), Size(411, 891)];

/// Deja correr mensajes, animaciones cortas y diálogos.
Future<void> _paso(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void _usarPantalla(WidgetTester tester, Size tamano) {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _abrirMenu(
  WidgetTester tester,
  ServidorFalso servidor, {
  RelojFalso? reloj,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BuscarPartidaScreen(
        usuario: const Usuario(nombre: 'ana', correo: 'ana@correo.com'),
        alCerrarSesion: () {},
        abrirSala: abrirSalaDePrueba(servidor, reloj: reloj),
      ),
    ),
  );
  await _paso(tester);
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _paso(tester);
}

/// Crea una sala desde Buscar partida y devuelve el canal con el servidor.
Future<CanalFalso> _crearSala(
  WidgetTester tester,
  ServidorFalso servidor, {
  int jugadores = 2,
}) async {
  await _tocar(tester, find.byKey(const Key('boton-crear-sala')));
  if (jugadores != 2) await _tocar(tester, find.text('$jugadores'));
  await _tocar(tester, find.byKey(const Key('confirmar-crear-sala')));
  return servidor.actual;
}

/// Entra a una sala y el servidor manda [sala]. Yo soy ana (id 7).
Future<CanalFalso> _entrar(
  WidgetTester tester,
  ServidorFalso servidor,
  Map<String, Object?> sala, {
  RelojFalso? reloj,
}) async {
  await _abrirMenu(tester, servidor, reloj: reloj);
  final canal = await _crearSala(tester, servidor);
  canal
    ..autenticado(7, 'ana')
    ..estado(sala);
  await _paso(tester);
  return canal;
}

Map<String, Object?> _lobby({
  bool soyAnfitrion = true,
  bool anaLista = false,
  bool betoListo = false,
  bool betoConectado = true,
}) => lobbyJson(
  jugadores: [
    if (soyAnfitrion) ...[
      jugadorJson(7, 'ana', anfitrion: true, listo: anaLista),
      jugadorJson(8, 'beto', listo: betoListo, conectado: betoConectado),
    ] else ...[
      jugadorJson(8, 'beto', anfitrion: true, listo: betoListo),
      jugadorJson(7, 'ana', listo: anaLista),
    ],
  ],
);

Map<String, Object?> _partida({
  int turnoDe = 7,
  int numero = 1,
  List<int> dados = const [1, 5],
  bool betoConectado = true,
  String anaEstado = 'jugando',
  int anaPuntos = 0,
  Map<String, Object?>? ultimoMovimiento,
  List<List<int>>? ordenZonas,
  int jugadores = 2,
}) {
  final nombres = ['ana', 'beto', 'cami', 'dani'];
  return partidaJson(
    turnoDe: turnoDe,
    numeroTurno: numero,
    dados: dados,
    ultimoMovimiento: ultimoMovimiento,
    ordenZonas: ordenZonas,
    jugadores: [
      for (var i = 0; i < jugadores; i++)
        jugadorJson(
          7 + i,
          nombres[i],
          estado: i == 0 ? anaEstado : 'jugando',
          numerosEnviados: true,
          conectado: i == 1 ? betoConectado : true,
          tablero: tableroInicial(),
          puntaje: i == 0 ? anaPuntos : 0,
        ),
    ],
  );
}

void main() {
  late ServidorFalso servidor;

  setUp(() => servidor = ServidorFalso());

  group('Buscar partida', () {
    testWidgets('crear sala pide los jugadores y manda el mapa elegido', (
      tester,
    ) async {
      await _abrirMenu(tester, servidor);
      await _tocar(tester, find.byKey(const Key('mapa-3')));
      await _tocar(tester, find.byKey(const Key('boton-crear-sala')));
      expect(find.text('Mapa 3'), findsWidgets);
      await _tocar(tester, find.text('4'));
      await _tocar(tester, find.byKey(const Key('confirmar-crear-sala')));

      expect(find.byKey(const Key('texto-conectando')), findsOneWidget);
      servidor.actual.autenticado(7, 'ana');
      await _paso(tester);
      expect(servidor.actual.ultimo('crear_sala'), {
        'tipo': 'crear_sala',
        'id': 1,
        'mapa': 3,
        'maximo': 4,
      });
    });

    testWidgets('unirse: mayúsculas automáticas y solo caracteres válidos', (
      tester,
    ) async {
      await _abrirMenu(tester, servidor);
      await _tocar(tester, find.byKey(const Key('boton-unirse')));
      final campo = find.byKey(const Key('campo-codigo-sala'));
      final unirse = find.byKey(const Key('confirmar-unirse'));

      await tester.enterText(campo, 'ab-c2');
      await tester.pump();
      expect(find.text('ABC2'), findsOneWidget);
      expect(tester.widget<FilledButton>(unirse).onPressed, isNull);

      // 0, O, 1, I y L no existen en los códigos; corta en 6.
      await tester.enterText(campo, 'ab-c0o1il23x9');
      await tester.pump();
      expect(find.text('ABC23X'), findsOneWidget);
      expect(tester.widget<FilledButton>(unirse).onPressed, isNotNull);

      await _tocar(tester, unirse);
      servidor.actual.autenticado(7, 'ana');
      await _paso(tester);
      expect(servidor.actual.ultimo('unirse')!['codigo'], 'ABC23X');
    });

    testWidgets('código inexistente: aviso claro y vuelve al menú', (
      tester,
    ) async {
      await _abrirMenu(tester, servidor);
      await _tocar(tester, find.byKey(const Key('boton-unirse')));
      await tester.enterText(
        find.byKey(const Key('campo-codigo-sala')),
        'ZZZZZZ',
      );
      await tester.pump();
      await _tocar(tester, find.byKey(const Key('confirmar-unirse')));
      servidor.actual
        ..autenticado(7, 'ana')
        ..error('sala_inexistente', 'No existe una sala con ese código', id: 1);
      await _paso(tester);

      expect(find.text('No existe una sala con ese código'), findsOneWidget);
      await _tocar(tester, find.byKey(const Key('aceptar-fin')));
      expect(find.text('Buscar partida'), findsWidgets);
      expect(find.byKey(const Key('boton-crear-sala')), findsOneWidget);
    });

    testWidgets('sala llena: aviso claro y vuelve al menú', (tester) async {
      await _abrirMenu(tester, servidor);
      await _tocar(tester, find.byKey(const Key('boton-unirse')));
      await tester.enterText(
        find.byKey(const Key('campo-codigo-sala')),
        'ABC234',
      );
      await tester.pump();
      await _tocar(tester, find.byKey(const Key('confirmar-unirse')));
      servidor.actual
        ..autenticado(7, 'ana')
        ..error('sala_llena', 'La sala está llena', id: 1);
      await _paso(tester);
      expect(find.text('La sala está llena'), findsOneWidget);
      await _tocar(tester, find.byKey(const Key('aceptar-fin')));
      expect(find.byKey(const Key('boton-unirse')), findsOneWidget);
    });

    testWidgets('servidor no disponible: aviso claro', (tester) async {
      servidor.disponible = false;
      await _abrirMenu(tester, servidor);
      await _crearSala(tester, servidor).catchError((_) => CanalFalso());
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await _paso(tester);
      expect(
        find.text(MensajesMultijugador.servidorNoDisponible),
        findsOneWidget,
      );
    });
  });

  group('Lobby', () {
    testWidgets('muestra código, jugadores, anfitrión, listo y desconectado', (
      tester,
    ) async {
      await _entrar(
        tester,
        servidor,
        _lobby(betoListo: true, betoConectado: false),
      );

      expect(find.byKey(const Key('codigo-sala')), findsOneWidget);
      expect(find.text('K7M2QX'), findsOneWidget);
      expect(find.text('ana (tú)'), findsOneWidget);
      expect(find.text('Anfitrión'), findsOneWidget);
      expect(find.text('Desconectado'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);
      expect(find.text('No listo'), findsOneWidget);
      expect(find.text('2 de 2 jugadores'), findsOneWidget);
      expect(find.text('Mapa 1'), findsOneWidget);
    });

    testWidgets('Copiar y Compartir copian el código y la invitación', (
      tester,
    ) async {
      final copiados = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (llamada) async {
          if (llamada.method == 'Clipboard.setData') {
            copiados.add((llamada.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _entrar(tester, servidor, _lobby());
      await _tocar(tester, find.byKey(const Key('copiar-codigo')));
      await _tocar(tester, find.byKey(const Key('compartir-codigo')));
      expect(copiados, ['K7M2QX', textoInvitacion('K7M2QX')]);
      expect(textoInvitacion('K7M2QX'), contains('Unirme con código'));
    });

    testWidgets('el anfitrión inicia solo con todos listos', (tester) async {
      final canal = await _entrar(tester, servidor, _lobby());
      final iniciar = find.byKey(const Key('boton-iniciar'));
      expect(tester.widget<FilledButton>(iniciar).onPressed, isNull);

      await _tocar(tester, find.byKey(const Key('boton-listo')));
      expect(canal.ultimo('listo')!['listo'], isTrue);
      // La app no se marca lista sola: espera al servidor.
      expect(find.text('Estoy listo'), findsOneWidget);

      canal.estado(_lobby(anaLista: true, betoListo: true));
      await _paso(tester);
      expect(find.text('Ya no estoy listo'), findsOneWidget);
      expect(tester.widget<FilledButton>(iniciar).onPressed, isNotNull);
      await _tocar(tester, iniciar);
      expect(canal.ultimo('iniciar'), isNotNull);
    });

    testWidgets('quien no es anfitrión no ve Iniciar', (tester) async {
      await _entrar(tester, servidor, _lobby(soyAnfitrion: false));
      expect(find.byKey(const Key('boton-iniciar')), findsNothing);
      expect(
        find.text('El anfitrión inicia la partida cuando todos estén listos.'),
        findsOneWidget,
      );
    });

    testWidgets('salir pide confirmación y vuelve al menú', (tester) async {
      final canal = await _entrar(tester, servidor, _lobby());
      await _tocar(tester, find.byKey(const Key('boton-salir-sala')));
      expect(find.text('¿Salir de la sala?'), findsOneWidget);
      await _tocar(tester, find.text('Cancelar'));
      expect(canal.de('salir'), isEmpty);

      await _tocar(tester, find.byKey(const Key('boton-salir-sala')));
      await _tocar(tester, find.byKey(const Key('confirmar-salir-sala')));
      expect(canal.de('salir'), hasLength(1));
      canal.recibir({'tipo': 'saliste', 'codigo': 'K7M2QX'});
      await _paso(tester);
      expect(find.byKey(const Key('boton-crear-sala')), findsOneWidget);
    });

    testWidgets('la sala que caduca avisa y vuelve al menú', (tester) async {
      final canal = await _entrar(tester, servidor, _lobby());
      canal.recibir({
        'tipo': 'sala_cerrada',
        'codigo': 'K7M2QX',
        'motivo': 'caducada',
        'mensaje': 'La sala se cerró porque la partida no empezó a tiempo',
      });
      await _paso(tester);
      expect(
        find.text('La sala se cerró porque la partida no empezó a tiempo'),
        findsOneWidget,
      );
      await _tocar(tester, find.byKey(const Key('aceptar-fin')));
      expect(find.byKey(const Key('boton-crear-sala')), findsOneWidget);
    });
  });

  group('Números iniciales', () {
    testWidgets('con el tiempo visible y luego espera a los demás', (
      tester,
    ) async {
      final canal = await _entrar(
        tester,
        servidor,
        partidaJson(
          fase: 'numeros',
          segundosParaNumeros: 90,
          jugadores: [
            jugadorJson(7, 'ana', estado: 'jugando'),
            jugadorJson(8, 'beto', estado: 'jugando'),
          ],
        ),
      );
      expect(find.textContaining('⏱ 90 s'), findsOneWidget);
      expect(find.text('Enviar mis números'), findsOneWidget);
      expect(find.byTooltip('Volver'), findsNothing);

      canal.estado(
        partidaJson(
          fase: 'numeros',
          segundosParaNumeros: 70,
          jugadores: [
            jugadorJson(7, 'ana', estado: 'jugando', numerosEnviados: true),
            jugadorJson(8, 'beto', estado: 'jugando'),
          ],
        ),
      );
      await _paso(tester);
      expect(find.byKey(const Key('esperando-numeros')), findsOneWidget);
      expect(find.text('Eligiendo…'), findsOneWidget);
    });
  });

  group('Partida', () {
    testWidgets('turno propio: tirar muestra los dados del servidor y coloca', (
      tester,
    ) async {
      final canal = await _entrar(tester, servidor, _partida());
      expect(find.byKey(const Key('texto-turno')), findsOneWidget);
      expect(find.text('Tu turno'), findsOneWidget);
      // Antes de tirar, los dados no se ven.
      expect(find.text('?'), findsNWidgets(2));
      expect(find.text('Tirar dados'), findsOneWidget);

      await _tocar(tester, find.byKey(const Key('boton-accion-turno')));
      expect(find.text('?'), findsNothing);
      expect(
        find.text('Toca un dado para elegirlo como ancla'),
        findsOneWidget,
      );

      await _tocar(tester, find.byKey(const Key('dado-0')));
      expect(find.text('ANCLA'), findsOneWidget);
      // Ancla 1, se coloca el 5: casillas (0,1) y (0,3).
      await _tocar(tester, find.byKey(const Key('celda-0-1')));
      expect(canal.ultimo('colocar'), {
        'tipo': 'colocar',
        'id': 2,
        'dadoAncla': 0,
        'fila': 0,
        'columna': 1,
      });
      expect(find.text('Enviando tu jugada…'), findsOneWidget);
    });

    testWidgets('turno ajeno: controles desactivados', (tester) async {
      final canal = await _entrar(tester, servidor, _partida(turnoDe: 8));
      expect(find.text('Turno de beto'), findsWidgets);
      final boton = find.byKey(const Key('boton-accion-turno'));
      expect(tester.widget<FilledButton>(boton).onPressed, isNull);
      await tester.tap(find.byKey(const Key('dado-0')));
      await _paso(tester);
      expect(find.text('ANCLA'), findsNothing);
      await tester.tap(find.byKey(const Key('celda-0-1')));
      await _paso(tester);
      expect(canal.de('colocar'), isEmpty);
      // Rendirse sí se puede siempre que siga jugando.
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('boton-rendirse')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('jugada rechazada: aviso y se puede volver a intentar', (
      tester,
    ) async {
      final canal = await _entrar(tester, servidor, _partida());
      await _tocar(tester, find.byKey(const Key('boton-accion-turno')));
      await _tocar(tester, find.byKey(const Key('dado-0')));
      await _tocar(tester, find.byKey(const Key('celda-0-1')));
      canal.error(
        'jugada_invalida',
        'No puedes colocar ese número en esa casilla',
        id: 2,
      );
      await _paso(tester);
      expect(
        find.text('No puedes colocar ese número en esa casilla'),
        findsOneWidget,
      );
      expect(find.text('Enviando tu jugada…'), findsNothing);
      await _tocar(tester, find.byKey(const Key('celda-0-3')));
      expect(canal.de('colocar'), hasLength(2));
    });

    testWidgets('lo confirmado por el servidor se ve en el tablero y puntos', (
      tester,
    ) async {
      final canal = await _entrar(tester, servidor, _partida());
      final tablero = tableroInicial()..[0][1] = 5;
      canal.estado(
        partidaJson(
          turnoDe: 8,
          numeroTurno: 2,
          jugadores: [
            jugadorJson(
              7,
              'ana',
              estado: 'jugando',
              tablero: tablero,
              puntaje: 7,
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
      await _paso(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('celda-0-1')),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      expect(tester.widget<Text>(find.byKey(const Key('puntos-7'))).data, '7');
    });

    testWidgets('aviso de quién completó una zona', (tester) async {
      final canal = await _entrar(tester, servidor, _partida());
      canal.estado(
        _partida(
          turnoDe: 8,
          numero: 2,
          anaPuntos: 7,
          ordenZonas: [
            [],
            [],
            [7],
            ...List.generate(6, (_) => <int>[]),
          ],
          ultimoMovimiento: {
            'tipo': 'colocacion',
            'jugador': 7,
            'turno': 1,
            'zonaCompletada': {
              'zona': 2,
              'nombre': 'Azul 1',
              'lugar': 1,
              'puntos': 7,
            },
          },
        ),
      );
      await _paso(tester);
      expect(find.text('+7 puntos'), findsOneWidget);
      expect(find.text('ana completó Azul 1 (1.º)'), findsOneWidget);
    });

    testWidgets('rendirse explica que quedará último y lo manda', (
      tester,
    ) async {
      final canal = await _entrar(tester, servidor, _partida(turnoDe: 8));
      await _tocar(tester, find.byKey(const Key('boton-rendirse')));
      expect(find.textContaining('quedarás en último lugar'), findsOneWidget);
      await _tocar(tester, find.text('Seguir jugando'));
      expect(canal.de('rendirse'), isEmpty);

      await _tocar(tester, find.byKey(const Key('boton-rendirse')));
      await _tocar(tester, find.byKey(const Key('confirmar-rendirse')));
      expect(canal.de('rendirse'), hasLength(1));

      canal.estado(_partida(turnoDe: 8, anaEstado: 'rendido'));
      await _paso(tester);
      expect(find.text('Te rendiste: quedas en último lugar.'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('boton-rendirse')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('rival desconectado con cuenta regresiva', (tester) async {
      final reloj = RelojFalso();
      final canal = await _entrar(tester, servidor, _partida(), reloj: reloj);
      canal.estado(_partida(betoConectado: false));
      await _paso(tester);
      expect(find.text('Desconectado · 60 s'), findsOneWidget);

      for (var i = 0; i < 5; i++) {
        reloj.avanzar(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('Desconectado · 55 s'), findsOneWidget);

      canal.estado(_partida());
      await _paso(tester);
      expect(find.textContaining('Desconectado'), findsNothing);
    });

    testWidgets('el tiempo del turno se ve y baja', (tester) async {
      final reloj = RelojFalso();
      await _entrar(tester, servidor, _partida(), reloj: reloj);
      expect(find.text('⏱ 60 s'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        reloj.avanzar(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('⏱ 57 s'), findsOneWidget);
    });

    testWidgets('reconexión: banner y estado completo al volver', (
      tester,
    ) async {
      final canal = await _entrar(tester, servidor, _partida(turnoDe: 8));
      canal.cortar(codigo: 1006);
      await _paso(tester);
      expect(find.byKey(const Key('banner-reconectando')), findsOneWidget);
      expect(find.text('Turno de beto'), findsWidgets);

      await tester.pump(const Duration(seconds: 1));
      await _paso(tester);
      final nuevo = servidor.actual;
      expect(nuevo, isNot(same(canal)));
      expect(nuevo.enviados.first['sala'], 'K7M2QX');
      nuevo
        ..autenticado(7, 'ana', sala: 'K7M2QX', ultimaAccion: 1)
        ..estado(_partida(turnoDe: 7, numero: 3, anaPuntos: 9));
      await _paso(tester);

      expect(find.byKey(const Key('banner-reconectando')), findsNothing);
      expect(find.text('Tu turno'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('puntos-7'))).data, '9');
    });

    testWidgets('si no vuelve a tiempo: aviso claro y regreso al menú', (
      tester,
    ) async {
      servidor.disponible = true;
      final canal = await _entrar(tester, servidor, _partida(turnoDe: 8));
      servidor.disponible = false;
      canal.cortar(codigo: 1006);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await _paso(tester);
      expect(find.text(MensajesMultijugador.sinConexion), findsOneWidget);
      await _tocar(tester, find.byKey(const Key('aceptar-fin')));
      expect(find.byKey(const Key('boton-crear-sala')), findsOneWidget);
    });

    testWidgets('si el servidor dice que abandoné, lo explica', (tester) async {
      final canal = await _entrar(tester, servidor, _partida(turnoDe: 8));
      canal.estado(_partida(turnoDe: 8, anaEstado: 'abandono'));
      await _paso(tester);
      expect(
        find.text('Se agotó el plazo: abandonaste la partida.'),
        findsOneWidget,
      );
      await _tocar(tester, find.byKey(const Key('volver-menu-fuera')));
      expect(canal.de('salir'), hasLength(1));
    });

    testWidgets('sesión abierta en otro lugar', (tester) async {
      final canal = await _entrar(tester, servidor, _partida(turnoDe: 8));
      canal
        ..recibir({'tipo': 'sesion_reemplazada', 'mensaje': '…'})
        ..cortar(codigo: 4002);
      await _paso(tester);
      expect(find.text(MensajesMultijugador.sesionReemplazada), findsOneWidget);
    });
  });

  group('Resultado', () {
    testWidgets('fin con empate, rendidos y volver al menú', (tester) async {
      final canal = await _entrar(
        tester,
        servidor,
        partidaJson(
          fase: 'terminada',
          jugadores: [
            jugadorJson(7, 'ana', estado: 'jugando', puntaje: 12),
            jugadorJson(8, 'beto', estado: 'jugando', puntaje: 12),
            jugadorJson(9, 'cami', estado: 'rendido', puntaje: 20),
          ],
          resultado: [
            {'id': 7, 'posicion': 1, 'puntaje': 12, 'estado': 'jugando'},
            {'id': 8, 'posicion': 1, 'puntaje': 12, 'estado': 'jugando'},
            {'id': 9, 'posicion': 3, 'puntaje': 20, 'estado': 'rendido'},
          ],
        ),
      );
      expect(find.text('Empate: ana y beto'), findsOneWidget);
      expect(find.text('Empate'), findsNWidgets(2));
      expect(find.text('Se rindió'), findsOneWidget);
      expect(find.text('20 pts'), findsOneWidget);
      expect(find.text('1.º'), findsNWidgets(2));
      expect(find.text('3.º'), findsOneWidget);

      await _tocar(tester, find.byKey(const Key('volver-menu')));
      expect(canal.de('salir'), hasLength(1));
      canal.recibir({'tipo': 'saliste', 'codigo': 'K7M2QX'});
      await _paso(tester);
      expect(find.byKey(const Key('boton-crear-sala')), findsOneWidget);
    });

    testWidgets('ganar y abandono', (tester) async {
      await _entrar(
        tester,
        servidor,
        partidaJson(
          fase: 'terminada',
          jugadores: [
            jugadorJson(7, 'ana', estado: 'jugando', puntaje: 30),
            jugadorJson(8, 'beto', estado: 'abandono', puntaje: 5),
          ],
          resultado: [
            {'id': 7, 'posicion': 1, 'puntaje': 30, 'estado': 'jugando'},
            {'id': 8, 'posicion': 2, 'puntaje': 5, 'estado': 'abandono'},
          ],
        ),
      );
      expect(find.text('¡Ganaste!'), findsOneWidget);
      expect(find.text('Abandonó'), findsOneWidget);
    });
  });

  group('Marcador', () {
    testWidgets('todos los estados de los jugadores', (tester) async {
      final reloj = RelojFalso();
      final sala = SalaRemota.desdeJson(
        partidaJson(
          turnoDe: 8,
          orden: [8, 7, 9, 10],
          jugadores: [
            jugadorJson(7, 'ana', estado: 'jugando', puntaje: 3),
            jugadorJson(8, 'beto', estado: 'jugando', puntaje: 11),
            jugadorJson(9, 'cami', estado: 'rendido', puntaje: 4),
            jugadorJson(10, 'dani', estado: 'jugando', conectado: false),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarcadorMultijugador(
              sala: sala,
              miId: 7,
              desconectadosDesde: {10: reloj.ahora},
              plazoReconexion: const Duration(seconds: 60),
              reloj: reloj.call,
            ),
          ),
        ),
      );
      expect(find.text('ana (tú)'), findsOneWidget);
      expect(find.text('Su turno'), findsOneWidget);
      expect(find.text('Rendido'), findsOneWidget);
      expect(find.text('Desconectado · 60 s'), findsOneWidget);
      expect(find.text('Conectado'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('puntos-8'))).data, '11');
      // En el orden de turnos.
      final x = [
        for (final id in [8, 7, 9, 10])
          tester.getTopLeft(find.byKey(Key('marcador-$id'))).dx,
      ];
      expect(x, [...x]..sort());
    });

    testWidgets('abandonó', (tester) async {
      final sala = SalaRemota.desdeJson(
        partidaJson(
          jugadores: [
            jugadorJson(7, 'ana', estado: 'jugando'),
            jugadorJson(8, 'beto', estado: 'abandono'),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarcadorMultijugador(
              sala: sala,
              miId: 7,
              desconectadosDesde: const {},
              plazoReconexion: const Duration(seconds: 60),
              reloj: DateTime.now,
            ),
          ),
        ),
      );
      expect(find.text('Abandonó'), findsOneWidget);
    });
  });

  group('Tamaños', () {
    for (final tamano in _pantallas) {
      final nombre = '${tamano.width.toInt()}x${tamano.height.toInt()}';

      testWidgets('menú en línea y lobby de 4 en $nombre', (tester) async {
        _usarPantalla(tester, tamano);
        await _abrirMenu(tester, servidor);
        expect(tester.takeException(), isNull);
        final crear = find.byKey(const Key('boton-crear-sala'));
        expect(tester.getRect(crear).bottom, lessThanOrEqualTo(tamano.height));
        final canal = await _crearSala(tester, servidor, jugadores: 4);
        canal
          ..autenticado(7, 'ana')
          ..estado(
            lobbyJson(
              maximo: 4,
              jugadores: [
                jugadorJson(7, 'ana', anfitrion: true, listo: true),
                jugadorJson(8, 'beto_con_nombre_largo', listo: true),
                jugadorJson(9, 'cami', conectado: false),
                jugadorJson(10, 'dani'),
              ],
            ),
          );
        await _paso(tester);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const Key('boton-salir-sala')));
        await _paso(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('partida de 4 en $nombre', (tester) async {
        _usarPantalla(tester, tamano);
        await _entrar(
          tester,
          servidor,
          _partida(jugadores: 4, betoConectado: false),
        );
        expect(tester.takeException(), isNull);
        for (final k in ['boton-accion-turno', 'boton-rendirse', 'dado-0']) {
          final r = tester.getRect(find.byKey(Key(k)));
          expect(r.bottom, lessThanOrEqualTo(tamano.height), reason: k);
          expect(r.right, lessThanOrEqualTo(tamano.width), reason: k);
        }
        await _tocar(tester, find.byKey(const Key('boton-rendirse')));
        expect(tester.takeException(), isNull);
      });

      testWidgets('números y resultado en $nombre', (tester) async {
        _usarPantalla(tester, tamano);
        final canal = await _entrar(
          tester,
          servidor,
          partidaJson(
            fase: 'numeros',
            segundosParaNumeros: 90,
            jugadores: [
              jugadorJson(7, 'ana', estado: 'jugando'),
              jugadorJson(8, 'beto', estado: 'jugando'),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
        canal.estado(
          partidaJson(
            fase: 'terminada',
            jugadores: [
              for (var i = 0; i < 4; i++)
                jugadorJson(7 + i, 'jugador$i', estado: 'jugando', puntaje: 9),
            ],
            resultado: [
              for (var i = 0; i < 4; i++)
                {'id': 7 + i, 'posicion': 1, 'puntaje': 9, 'estado': 'jugando'},
            ],
          ),
        );
        await _paso(tester);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const Key('volver-menu')));
        await _paso(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('juegoDesdeTablero rearma las jugadas posibles', () {
    final juego = juegoDesdeTablero(
      SalaRemota.desdeJson(
        partidaJson(jugadores: [jugadorJson(7, 'ana', estado: 'jugando')]),
      ).nivel,
      tableroInicial(),
    )!;
    expect(juego.jugadasPosibles(ancla: 1, aColocar: 5), {(0, 1), (0, 3)});
    expect(EstadoConexion.values, contains(EstadoConexion.reconectando));
  });
}
