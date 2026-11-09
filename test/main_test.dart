import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/main.dart' as app;

void main() {
  // main() usa el repositorio real del servidor con flutter_secure_storage.
  // Leer la sesión guardada es E/S real, que no avanza con el tiempo falso de
  // testWidgets: por eso se deja correr dentro de runAsync. Sin sesión
  // guardada no se hace ninguna petición, así que no hace falta red.
  testWidgets('main() arranca la app y termina en el inicio de sesión', (
    tester,
  ) async {
    await tester.runAsync(() async {
      app.main();
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (find.text('Crear cuenta').evaluate().isNotEmpty) break;
      }
    });
    await tester.pump();

    expect(find.text('BRILLIANT'), findsOneWidget);
    expect(find.text('Entra para buscar una partida'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
