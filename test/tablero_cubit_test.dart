import 'package:flutter_test/flutter_test.dart';
import 'package:juego_brilliant/tablero_cubit.dart';
import 'package:juego_brilliant/tipo.dart';
import 'package:juego_brilliant/zona.dart';

void main() {
  test('empieza bloqueado y ignora valores', () {
    final cubit = TableroCubit();
    cubit.agregarValor('azul', 4);
    expect(cubit.state, isA<TableroSinIniciar>());
  });

  test('no inicia si no hay zonas', () {
    final cubit = TableroCubit();
    cubit.iniciar(id: 't1', zonas: []);
    expect(cubit.state, isA<TableroSinIniciar>());
  });

  test('inicia y permite agregar valores', () {
    final cubit = TableroCubit();
    cubit.iniciar(
      id: 't1',
      zonas: const [Zona(id: 'azul', tipo: Tipo.azul, capacidad: 3)],
    );
    cubit.agregarValor('azul', 4);

    final estado = cubit.state as TableroListo;
    expect(estado.tablero.zonaPorId('azul').valores, [4]);
  });
}