import 'tipo.dart';

const _r = Tipo.rojo;
const _a = Tipo.amarillo;
const _v = Tipo.verde;
const _z = Tipo.azul;
const _m = Tipo.morado;
const _b = Tipo.blanco;
const _n = Tipo.naranja46;
const _o = Tipo.naranja13;

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

/// Tablero del mapa 2.
const List<List<Tipo>> layoutTableroNivel2 = [
  [_m, _m, _m, _b, _v, _v, _v],
  [_m, _a, _z, _z, _z, _a, _v],
  [_m, _r, _r, _z, _z, _r, _v],
  [_r, _r, _r, _a, _r, _r, _r],
  [_v, _r, _z, _z, _r, _r, _m],
  [_v, _a, _z, _z, _z, _a, _m],
  [_v, _v, _v, _b, _m, _m, _m],
];

const List<PosicionCasilla> casillasEstrellaNivel2 = [
  PosicionCasilla(0, 4), // verde
  PosicionCasilla(2, 0), // morado
  PosicionCasilla(3, 2), // rojo
  PosicionCasilla(4, 5), // rojo
  PosicionCasilla(5, 1), // amarillo
  PosicionCasilla(6, 4), // morado
];

/// Tablero del mapa 3.
const List<List<Tipo>> layoutTableroNivel3 = [
  [_a, _a, _m, _b, _m, _a, _a],
  [_b, _a, _m, _m, _m, _a, _b],
  [_r, _r, _r, _m, _r, _r, _r],
  [_r, _r, _r, _b, _r, _r, _r],
  [_v, _z, _z, _z, _z, _z, _v],
  [_v, _v, _v, _v, _v, _v, _v],
  [_m, _m, _m, _b, _m, _m, _m],
];

const List<PosicionCasilla> casillasEstrellaNivel3 = [
  PosicionCasilla(1, 2), // morado
  PosicionCasilla(1, 5), // amarillo
  PosicionCasilla(3, 3), // blanco
  PosicionCasilla(4, 1), // azul
  PosicionCasilla(4, 6), // verde
  PosicionCasilla(6, 2), // morado
];

/// Tablero del mapa 4.
const List<List<Tipo>> layoutTableroNivel4 = [
  [_n, _n, _n, _n, _n, _n, _n],
  [_a, _r, _z, _v, _z, _r, _a],
  [_r, _r, _m, _m, _m, _r, _r],
  [_a, _v, _z, _m, _z, _v, _a],
  [_r, _r, _m, _m, _m, _r, _r],
  [_a, _r, _z, _v, _z, _r, _a],
  [_o, _o, _o, _o, _o, _o, _o],
];

const List<PosicionCasilla> casillasEstrellaNivel4 = [
  PosicionCasilla(0, 4), // naranja 4-6
  PosicionCasilla(2, 2), // morado
  PosicionCasilla(2, 5), // rojo
  PosicionCasilla(3, 0), // amarillo
  PosicionCasilla(5, 4), // azul
  PosicionCasilla(6, 1), // naranja 1-3
];