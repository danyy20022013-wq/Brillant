import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/juego_screen.dart';

const _numeros = [1, 2, 3, 4, 5, 6];

void main() {
  testWidgets('individual: muestra el turno y deja tirar los dados',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: JuegoScreen(iniciales: [_numeros])),
    );

    expect(find.text('Turno 1'), findsOneWidget);
    expect(find.text('PUNTOS'), findsOneWidget);
    expect(find.text('Tirar dados'), findsOneWidget);

    await tester.tap(find.text('Tirar dados'));
    await tester.pump();

    expect(find.text('Tirar dados'), findsNothing);
  });

  testWidgets('con dos jugadores muestra de quién es el turno',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: JuegoScreen(iniciales: [_numeros, _numeros])),
    );

    expect(find.text('Turno: Jugador 1'), findsOneWidget);
    expect(find.text('JUGADOR 2'), findsOneWidget);
  });

  testWidgets('el botón ? abre las reglas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: JuegoScreen(iniciales: [_numeros])),
    );

    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Reglas del juego'), findsOneWidget);
  });

  testWidgets('cabe en la pantalla de un celular sin desbordarse',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: JuegoScreen(iniciales: [_numeros])),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tirar dados'), findsOneWidget);
  });
}