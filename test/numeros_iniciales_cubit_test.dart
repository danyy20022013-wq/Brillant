import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/numeros_iniciales_cubit.dart';

void main() {
  test('empieza vacío e inválido', () {
    final cubit = NumerosInicialesCubit();
    expect(cubit.state.completo, isFalse);
    expect(cubit.state.esValido, isFalse);
  });

  test('es válido con 6 números distintos', () {
    final cubit = NumerosInicialesCubit();
    for (var i = 0; i < 6; i++) {
      cubit.seleccionar(i, i + 1);
    }
    expect(cubit.state.esValido, isTrue);
  });

  test('detecta números repetidos y marca la casilla', () {
    final cubit = NumerosInicialesCubit();
    cubit.seleccionar(0, 3);
    cubit.seleccionar(1, 3);
    expect(cubit.state.tieneRepetidos, isTrue);
    expect(cubit.state.casillaRepetida(0), isTrue);
    expect(cubit.state.casillaRepetida(2), isFalse);
  });

  test('con repetidos no es válido aunque esté completo', () {
    final cubit = NumerosInicialesCubit();
    for (var i = 0; i < 6; i++) {
      cubit.seleccionar(i, 1);
    }
    expect(cubit.state.completo, isTrue);
    expect(cubit.state.esValido, isFalse);
  });
}