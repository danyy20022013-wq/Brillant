import 'package:reglas_brilliant/reglas_brilliant.dart';
import 'package:test/test.dart';

void main() {
  group('puntosPorLugar', () {
    test('da los puntos del 1.º, 2.º y 3.º', () {
      expect(puntosPorLugar([7, 5, 3], 0), 7);
      expect(puntosPorLugar([7, 5, 3], 1), 5);
      expect(puntosPorLugar([7, 5, 3], 2), 3);
    });

    test('del 4.º en adelante y sin lugar ya no puntúa', () {
      expect(puntosPorLugar([7, 5, 3], 3), 0);
      expect(puntosPorLugar([7, 5, 3], 10), 0);
      expect(puntosPorLugar([7, 5, 3], -1), 0);
    });
  });

  group('puntaje por orden de llenado', () {
    final estructura = nivel1.estructura;
    final azul1 = estructura.indiceZona[0][2];
    final azul2 = estructura.indiceZona[4][6];
    final amarilla = estructura.indiceZona[0][0];

    List<List<int>> vacio() =>
        List.generate(estructura.zonas.length, (_) => <int>[]);

    test('cada jugador recibe los puntos de su lugar en la zona', () {
      final orden = vacio()..[azul1].addAll([0, 1, 2, 3]);
      expect(puntosEnZona(estructura, orden, 0, azul1), 7);
      expect(puntosEnZona(estructura, orden, 1, azul1), 5);
      expect(puntosEnZona(estructura, orden, 2, azul1), 3);
      expect(puntosEnZona(estructura, orden, 3, azul1), 0);
    });

    test('quien no llenó la zona tiene 0', () {
      final orden = vacio()..[azul1].add(1);
      expect(puntosEnZona(estructura, orden, 0, azul1), 0);
      expect(puntosEnZona(estructura, orden, 0, azul2), 0);
    });

    test('el total suma todas las zonas y no mezcla zonas iguales', () {
      final orden = vacio()
        ..[azul1].addAll([1, 0])
        ..[azul2].add(0)
        ..[amarilla].add(0);
      // azul 1 de 2.º (5) + azul 2 de 1.º (7) + amarilla de 1.º (8).
      expect(puntajeTotal(estructura, orden, 0), 20);
      expect(puntajeTotal(estructura, orden, 1), 7);
      expect(puntajeTotal(estructura, orden, 2), 0);
    });
  });
}
