import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/juego.dart';
import 'package:juego_brilliant/juego_cubit.dart';
import 'package:juego_brilliant/juego_screen.dart';
import 'package:juego_brilliant/tipo.dart';

const _iniciales = [1, 2, 3, 4, 5, 6];

Future<void> _abrir(
  WidgetTester tester, {
  required Nivel nivel,
  int jugadores = 1,
  Size? tamano,
}) async {
  if (tamano != null) {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MaterialApp(
      home: JuegoScreen(
        iniciales: List.filled(jugadores, _iniciales),
        nivel: nivel,
      ),
    ),
  );
}

JuegoCubit _cubit(WidgetTester tester) =>
    tester.element(find.byKey(const Key('dado-0'))).read<JuegoCubit>();

void _jugar(JuegoCubit cubit, int ancla, int valor, int f, int c) {
  cubit.fijarDados(ancla, valor);
  cubit.elegirAncla(0);
  cubit.colocar(f, c);
}

/// En el mapa 3, cada jugador completa Amarillo 2 (2 jugadas por jugador).
void _completarAmarillo2(JuegoCubit cubit, int jugadores) {
  for (var j = 0; j < jugadores; j++) {
    _jugar(cubit, 2, 4, 0, 5);
  }
  for (var j = 0; j < jugadores; j++) {
    _jugar(cubit, 4, 5, 0, 6);
  }
}

/// Juega la primera jugada posible hasta que se complete alguna zona.
ZonaCompletada _jugarHastaCompletar(JuegoCubit cubit) {
  for (var turno = 0; turno < 200; turno++) {
    (int, int, (int, int))? jugada;
    for (var a = 1; a <= 6 && jugada == null; a++) {
      for (var b = 1; b <= 6 && jugada == null; b++) {
        final posibles =
            cubit.state.juego.jugadasPosibles(ancla: a, aColocar: b);
        if (posibles.isNotEmpty) jugada = (a, b, posibles.first);
      }
    }
    final (a, b, (f, c)) = jugada!;
    _jugar(cubit, a, b, f, c);
    if (cubit.state.zonaCompletada != null) return cubit.state.zonaCompletada!;
  }
  throw StateError('no se completó ninguna zona');
}

/// La caja visible del aviso (sin el margen del SnackBar flotante).
final _cajaAviso = find
    .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
    .first;

SnackBar _aviso(WidgetTester tester) =>
    tester.widget<SnackBar>(find.byType(SnackBar));

Color _colorBorde(WidgetTester tester) {
  final forma = _aviso(tester).shape! as RoundedRectangleBorder;
  return forma.side.color;
}

/// Deja pasar el aviso actual (3 s) y su animación de salida.
Future<void> _siguienteAviso(WidgetTester tester) async {
  await tester.pump(duracionAvisoZona);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra los puntos en grande, el nombre y el color de la zona',
      (tester) async {
    await _abrir(tester, nivel: nivel3);
    _completarAmarillo2(_cubit(tester), 1);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('+7 puntos'), findsOneWidget);
    expect(find.text('Amarillo 2 completada'), findsOneWidget);
    expect(_colorBorde(tester), Tipo.amarillo.color);
    expect(_aviso(tester).behavior, SnackBarBehavior.floating);

    final grande = tester.widget<Text>(find.text('+7 puntos'));
    final chico = tester.widget<Text>(find.text('Amarillo 2 completada'));
    expect(grande.style!.fontSize!, greaterThan(chico.style!.fontSize!));

    // Se conserva la línea de texto junto a los dados.
    expect(find.text('Completaste Amarillo 2: +7 puntos'), findsOneWidget);
  });

  testWidgets('desaparece solo a los 3 segundos', (tester) async {
    await _abrir(tester, nivel: nivel3);
    _completarAmarillo2(_cubit(tester), 1);
    await tester.pumpAndSettle();

    expect(_aviso(tester).duration, const Duration(seconds: 3));
    expect(duracionAvisoZona, const Duration(seconds: 3));

    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('+7 puntos'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('no bloquea el tablero, los dados ni los botones',
      (tester) async {
    await _abrir(tester, nivel: nivel3);
    final cubit = _cubit(tester);
    _completarAmarillo2(cubit, 1);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    // El aviso queda entre el tablero y los botones.
    final aviso = tester.getRect(_cajaAviso);
    final ultimaFila = tester.getRect(find.byKey(const Key('celda-6-3')));
    final boton = tester.getRect(find.widgetWithText(FilledButton, 'Tirar dados'));
    expect(aviso.top, greaterThanOrEqualTo(ultimaFila.bottom));
    expect(aviso.bottom, lessThanOrEqualTo(boton.top));

    // Con el aviso visible se puede seguir jugando.
    await tester.tap(find.text('Tirar dados'));
    await tester.pumpAndSettle();
    expect(cubit.state.hayDados, isTrue);
    await tester.tap(find.byKey(const Key('dado-0')));
    await tester.pump();
    expect(cubit.state.indiceAncla, 0);

    await _siguienteAviso(tester);
  });

  testWidgets('varios avisos seguidos se encolan sin pisarse; el 4.º no puntúa',
      (tester) async {
    await _abrir(tester, nivel: nivel3, jugadores: 4);
    _completarAmarillo2(_cubit(tester), 4);
    await tester.pumpAndSettle();

    // Solo se ve el primero.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('+7 puntos'), findsOneWidget);
    expect(find.text('+5 puntos'), findsNothing);

    await _siguienteAviso(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('+5 puntos'), findsOneWidget);
    expect(find.text('+7 puntos'), findsNothing);

    await _siguienteAviso(tester);
    expect(find.text('+3 puntos'), findsOneWidget);

    await _siguienteAviso(tester);
    expect(find.text('Ya no puntúa'), findsOneWidget);
    expect(find.text('Amarillo 2 completada'), findsOneWidget);
    expect(find.textContaining('+0'), findsNothing);
    expect(_colorBorde(tester), Tipo.amarillo.color);

    await _siguienteAviso(tester);
    expect(find.byType(SnackBar), findsNothing);
  });

  for (final mapa in nivelesDisponibles) {
    testWidgets('mapa ${mapa.numero}: el aviso usa los puntos y el color '
        'de la zona', (tester) async {
      await _abrir(tester, nivel: mapa);
      final evento = _jugarHastaCompletar(_cubit(tester));
      await tester.pumpAndSettle();

      final zona = mapa.estructura.zonas[evento.zona];
      expect(find.text('+${zona.puntos.first} puntos'), findsOneWidget);
      expect(find.text('${zona.nombre} completada'), findsOneWidget);
      expect(_colorBorde(tester), zona.tipo.color);

      await _siguienteAviso(tester);
    });
  }

  const pantallas = [Size(320, 568), Size(360, 640), Size(411, 891)];
  for (final tamano in pantallas) {
    testWidgets(
        'cabe sin desbordes en ${tamano.width.toInt()}x${tamano.height.toInt()}',
        (tester) async {
      await _abrir(tester, nivel: nivel3, tamano: tamano);
      _completarAmarillo2(_cubit(tester), 1);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('+7 puntos'), findsOneWidget);
      final aviso = tester.getRect(_cajaAviso);
      final ultimaFila = tester.getRect(find.byKey(const Key('celda-6-3')));
      expect(aviso.top, greaterThanOrEqualTo(ultimaFila.bottom));

      await _siguienteAviso(tester);
    });
  }
}
