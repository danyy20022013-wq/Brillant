import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/tipo.dart';
import 'package:juego_brilliant/juego_cubit.dart';
import 'package:juego_brilliant/juego_screen.dart';

const _numeros = [1, 2, 3, 4, 5, 6];

/// Mapa de prueba todo azul (una sola zona con 1..6): nunca hay jugadas,
/// porque el azul exige que todos sean iguales.
final _mapaSinJugadas = Nivel(
  numero: 9,
  layout: List.generate(7, (_) => List.filled(7, Tipo.azul)),
  estrellas: const [
    PosicionCasilla(0, 0),
    PosicionCasilla(0, 6),
    PosicionCasilla(3, 3),
    PosicionCasilla(5, 1),
    PosicionCasilla(6, 0),
    PosicionCasilla(6, 6),
  ],
  zonaUnica: const {},
  puntos: const {
    Tipo.azul: [7, 5, 3],
  },
);

Future<void> _abrir(WidgetTester tester, {Nivel? nivel, Size? tamano}) async {
  if (tamano != null) {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MaterialApp(
      home: JuegoScreen(iniciales: const [_numeros], nivel: nivel),
    ),
  );
}

JuegoCubit _cubit(WidgetTester tester) =>
    tester.element(find.byKey(const Key('dado-0'))).read<JuegoCubit>();

double _angulo(WidgetTester tester, int dado) {
  final giro = tester.widget<Transform>(
    find
        .descendant(
          of: find.byKey(Key('dado-$dado')),
          matching: find.byType(Transform),
        )
        .first,
  );
  // El ángulo se lee de la matriz: cos en [0], sin en [1].
  final m = giro.transform.storage;
  return m[1] == 0 && m[0] == 1 ? 0 : 1;
}

/// Puntitos dibujados en la cara del dado.
int _puntos(WidgetTester tester, int dado) => find
    .descendant(
      of: find.byKey(Key('dado-$dado')),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    )
    .evaluate()
    .length;

void main() {
  group('Giro de los dados', () {
    testWidgets('al tirar giran y al terminar muestran el valor del cubit',
        (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Tirar dados'));
      await tester.pump(); // primer frame: arranca la animación
      await tester.pump(const Duration(milliseconds: 150));

      // Durante el giro.
      expect(find.text('Tirando los dados…'), findsOneWidget);
      expect(_angulo(tester, 0), isNot(0));

      await tester.pumpAndSettle();

      // Al terminar: quietos y con el valor que decidió el cubit.
      final estado = _cubit(tester).state;
      expect(estado.hayDados, isTrue);
      expect(find.text('Tirando los dados…'), findsNothing);
      expect(_angulo(tester, 0), 0);
      expect(_angulo(tester, 1), 0);
      expect(_puntos(tester, 0), estado.dado1);
      expect(_puntos(tester, 1), estado.dado2);
    });

    testWidgets('la animación dura lo indicado (entre 400 y 600 ms)',
        (tester) async {
      expect(duracionGiroDados.inMilliseconds, inInclusiveRange(400, 600));

      await _abrir(tester);
      await tester.tap(find.text('Tirar dados'));
      await tester.pump();
      await tester.pump(duracionGiroDados - const Duration(milliseconds: 50));
      expect(find.text('Tirando los dados…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      expect(find.text('Tirando los dados…'), findsNothing);
    });

    testWidgets('mientras giran no se pueden tocar dados, casillas ni botón',
        (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Tirar dados'));
      await tester.pump(const Duration(milliseconds: 100));

      final cubit = _cubit(tester);
      final antes = cubit.state;

      await tester.tap(find.byKey(const Key('dado-0')), warnIfMissed: false);
      await tester.pump();
      expect(cubit.state.indiceAncla, isNull);

      await tester.tap(find.byKey(const Key('celda-0-1')), warnIfMissed: false);
      await tester.pump();
      expect(cubit.state.juego, antes.juego);

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Saltar turno'),
      );
      expect(boton.onPressed, isNull);

      // Al terminar el giro ya se puede elegir el ancla.
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dado-0')));
      await tester.pump();
      expect(cubit.state.indiceAncla, 0);
    });
  });

  group('Saltar turno', () {
    testWidgets('no aparece antes de tirar; aparece con dados tirados',
        (tester) async {
      await _abrir(tester);
      expect(find.text('Saltar turno'), findsNothing);
      expect(find.text('Pasar turno'), findsNothing);

      _cubit(tester).fijarDados(1, 1); // hay jugadas
      await tester.pump();

      expect(find.text('Saltar turno'), findsOneWidget);
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Saltar turno'),
      );
      expect(boton.onPressed, isNotNull);
    });

    testWidgets('con jugadas avisa y al cancelar no pasa nada',
        (tester) async {
      await _abrir(tester);
      final cubit = _cubit(tester)..fijarDados(1, 1);
      await tester.pump();
      expect(cubit.state.hayJugadas, isTrue);

      await tester.tap(find.text('Saltar turno'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('Todavía tienes jugadas posibles. ¿Quieres saltar el turno?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(cubit.state.turno, 1);
      expect(cubit.state.dado1, 1);
      expect(cubit.state.dado2, 1);
    });

    testWidgets('con jugadas, al confirmar se salta el turno', (tester) async {
      await _abrir(tester);
      final cubit = _cubit(tester)..fijarDados(1, 1);
      await tester.pump();

      await tester.tap(find.text('Saltar turno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saltar'));
      await tester.pumpAndSettle();

      expect(cubit.state.turno, 2);
      expect(cubit.state.hayDados, isFalse);
      expect(find.text('Tirar dados'), findsOneWidget);
      expect(find.text('Saltaste el turno'), findsOneWidget);
    });

    testWidgets('sin jugadas lo dice y al confirmar se salta el turno',
        (tester) async {
      await _abrir(tester, nivel: _mapaSinJugadas);
      final cubit = _cubit(tester)..fijarDados(2, 3);
      await tester.pump();
      expect(cubit.state.hayJugadas, isFalse);

      await tester.tap(find.text('Saltar turno'));
      await tester.pumpAndSettle();

      expect(
        find.text('No tienes jugadas posibles con estos dados.'),
        findsOneWidget,
      );
      expect(find.textContaining('Todavía tienes'), findsNothing);

      await tester.tap(find.text('Saltar'));
      await tester.pumpAndSettle();
      expect(cubit.state.turno, 2);
      expect(cubit.state.hayDados, isFalse);
    });

    testWidgets('sin jugadas, cancelar tampoco hace nada', (tester) async {
      await _abrir(tester, nivel: _mapaSinJugadas);
      final cubit = _cubit(tester)..fijarDados(2, 3);
      await tester.pump();

      await tester.tap(find.text('Saltar turno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(cubit.state.turno, 1);
      expect(cubit.state.hayDados, isTrue);
    });
  });

  group('Celulares con dados y diálogo', () {
    const pantallas = [Size(320, 568), Size(360, 640), Size(411, 891)];
    for (final tamano in pantallas) {
      testWidgets('${tamano.width.toInt()}x${tamano.height.toInt()}',
          (tester) async {
        await _abrir(tester, tamano: tamano);
        await tester.tap(find.text('Tirar dados'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Saltar turno'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsOneWidget);
      });
    }
  });
}
