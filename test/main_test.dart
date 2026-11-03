import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/main.dart' as app;

void main() {
  testWidgets('main() arranca la app en el inicio de sesión', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('BRILLIANT'), findsOneWidget);
    expect(find.text('Entra para buscar una partida'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });
}
