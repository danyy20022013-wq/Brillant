import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/main.dart';

/// Toca la primera estrella que aún esté vacía y elige [numero].
Future<void> _elegir(WidgetTester tester, int numero) async {
  await tester.tap(find.byIcon(Icons.star_rounded).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('$numero').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('con números repetidos avisa y no deja iniciar', (tester) async {
    await tester.pumpWidget(const BrilliantApp());

    await _elegir(tester, 1);
    await _elegir(tester, 1);

    expect(find.text('Los números no pueden repetirse'), findsOneWidget);
    final inicio = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Inicio'),
    );
    expect(inicio.onPressed, isNull);
  });

  testWidgets('con 6 números distintos entra al juego', (tester) async {
    await tester.pumpWidget(const BrilliantApp());

    for (var n = 1; n <= 6; n++) {
      await _elegir(tester, n);
    }

    final inicio = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Inicio'),
    );
    expect(inicio.onPressed, isNotNull);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();

    expect(find.text('Tirar dados'), findsOneWidget);
    expect(find.text('Turno 1'), findsOneWidget);
  });
}