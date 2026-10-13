import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/juego_screen.dart';

void main() {
  testWidgets('muestra los puntos y permite tirar los dados', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: JuegoScreen(iniciales: [1, 2, 3, 4, 5, 6])),
    );

    expect(find.text('PUNTOS'), findsOneWidget);
    expect(find.text('Tirar dados'), findsOneWidget);

    await tester.tap(find.text('Tirar dados'));
    await tester.pump();

    expect(find.text('Tirar dados'), findsNothing);
  });
}