import 'tipo.dart';

const _r = Tipo.rojo;
const _a = Tipo.amarillo;
const _v = Tipo.verde;
const _z = Tipo.azul;
const _m = Tipo.morado;

/// Tablero del nivel 1: 7 filas x 7 columnas, cada casilla con su tipo.
const List<List<Tipo>> layoutTableroNivel1 = [
  [_a, _v, _z, _m, _m, _m, _a],
  [_v, _v, _z, _z, _m, _m, _v],
  [_v, _r, _r, _z, _m, _v, _v],
  [_v, _r, _m, _a, _v, _v, _v],
  [_v, _r, _m, _m, _r, _r, _z],
  [_r, _r, _m, _r, _r, _z, _z],
  [_a, _m, _m, _r, _r, _z, _a],
];

class PosicionCasilla {
  final int fila;
  final int columna;

  const PosicionCasilla(this.fila, this.columna);
}

/// Las 6 casillas con estrella. El índice coincide con el de
/// NumerosInicialesCubit.
const List<PosicionCasilla> casillasEstrella = [
  PosicionCasilla(0, 2), // azul
  PosicionCasilla(1, 5), // morado
  PosicionCasilla(3, 1), // rojo
  PosicionCasilla(3, 4), // verde
  PosicionCasilla(5, 2), // morado
  PosicionCasilla(6, 4), // rojo
];