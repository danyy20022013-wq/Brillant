import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/tipo.dart';
import 'package:juego_brilliant/juego_cubit.dart';
import 'package:juego_brilliant/juego_screen.dart';

const _iniciales = [1, 2, 3, 4, 5, 6];

Future<void> _abrir(
  WidgetTester tester, {
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
        nivel: nivel3,
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

void _saltar(JuegoCubit cubit) {
  cubit.fijarDados(1, 1);
  cubit.pasarTurno();
}

/// Juega muchos turnos (la primera jugada posible) para llenar la lista.
void _jugarMucho(JuegoCubit cubit, int turnos) {
  for (var t = 0; t < turnos && !cubit.state.terminado; t++) {
    (int, int, (int, int))? jugada;
    for (var a = 1; a <= 6 && jugada == null; a++) {
      for (var b = 1; b <= 6 && jugada == null; b++) {
        final posibles =
            cubit.state.juego.jugadasPosibles(ancla: a, aColocar: b);
        if (posibles.isNotEmpty) jugada = (a, b, posibles.first);
      }
    }
    if (jugada == null) {
      _saltar(cubit);
    } else {
      final (a, b, (f, c)) = jugada;
      _jugar(cubit, a, b, f, c);
    }
  }
}

Future<void> _abrirHistorial(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Historial'));
  await tester.pumpAndSettle();
}

String _texto(WidgetTester tester, int i) =>
    tester.widget<Text>(find.byKey(Key('movimiento-$i'))).data!;

/// Cierra los avisos de zona completada para que no queden temporizadores.
Future<void> _cerrarAvisos(WidgetTester tester) async {
  await tester.pump(duracionAvisoZona);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el botón Historial está en el encabezado', (tester) async {
    await _abrir(tester);
    expect(find.byTooltip('Historial'), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
  });

  testWidgets('sin movimientos dice que todavía no hay', (tester) async {
    await _abrir(tester);
    await _abrirHistorial(tester);

    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Todavía no hay movimientos'), findsOneWidget);
    expect(find.byKey(const Key('movimiento-0')), findsNothing);
  });

  testWidgets('muestra los movimientos del más reciente al más antiguo',
      (tester) async {
    await _abrir(tester);
    final cubit = _cubit(tester);
    _jugar(cubit, 2, 4, 0, 5);
    _saltar(cubit);
    _jugar(cubit, 4, 5, 0, 6);
    await tester.pump();
    await _abrirHistorial(tester);

    expect(find.text('Todavía no hay movimientos'), findsNothing);
    expect(
      _texto(tester, 0),
      'Turno 3: colocaste un 5 junto a un 4 en la fila 1, columna 7 '
      '(Amarillo 2)',
    );
    expect(_texto(tester, 1), 'Turno 2: saltaste el turno');
    expect(
      _texto(tester, 2),
      'Turno 1: colocaste un 4 junto a un 2 en la fila 1, columna 6 '
      '(Amarillo 2)',
    );
    expect(find.byKey(const Key('movimiento-3')), findsNothing);

    await tester.tapAt(const Offset(10, 10));
    await _cerrarAvisos(tester);
  });

  testWidgets('con varios jugadores usa J1, J2...', (tester) async {
    await _abrir(tester, jugadores: 2);
    final cubit = _cubit(tester);
    _jugar(cubit, 2, 4, 0, 5); // J1
    _saltar(cubit); // J2
    await tester.pump();
    await _abrirHistorial(tester);

    expect(_texto(tester, 0), 'Turno 2: J2 saltó el turno');
    expect(
      _texto(tester, 1),
      'Turno 1: J1 colocó un 4 junto a un 2 en la fila 1, columna 6 '
      '(Amarillo 2)',
    );
  });

  testWidgets('se cierra al tocar fuera', (tester) async {
    await _abrir(tester);
    await _abrirHistorial(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay movimientos'), findsNothing);
  });

  const pantallas = [Size(320, 568), Size(360, 640), Size(411, 891)];
  for (final tamano in pantallas) {
    final nombre = '${tamano.width.toInt()}x${tamano.height.toInt()}';

    testWidgets('$nombre: el encabezado no se desborda', (tester) async {
      await _abrir(tester, tamano: tamano, jugadores: 2);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Historial'), findsOneWidget);
      expect(find.byTooltip('Reglas'), findsOneWidget);
    });

    testWidgets('$nombre: lista larga sin desbordes y se desplaza',
        (tester) async {
      await _abrir(tester, tamano: tamano);
      final cubit = _cubit(tester);
      _jugarMucho(cubit, 30);
      await tester.pump();
      final total = cubit.state.historial.length;
      expect(total, greaterThan(10));

      await _abrirHistorial(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('movimiento-0')), findsOneWidget);

      // Se puede bajar hasta el movimiento más antiguo (turno 1).
      await tester.scrollUntilVisible(
        find.byKey(Key('movimiento-${total - 1}')),
        200,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      expect(_texto(tester, total - 1), startsWith('Turno 1: '));
      expect(tester.takeException(), isNull);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      // Deja pasar los avisos de zonas completadas.
      for (var i = 0; i < 12; i++) {
        await _cerrarAvisos(tester);
      }
    });
  }
}
