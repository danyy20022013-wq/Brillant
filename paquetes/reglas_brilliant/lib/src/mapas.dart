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

/// Nombre del tipo en pantalla. Tipo es "sealed": si se agrega un tipo
/// nuevo y falta aquí, el compilador avisa.
String nombreDe(Tipo tipo) => switch (tipo) {
  TipoRojo() => 'Rojo',
  TipoAmarillo() => 'Amarillo',
  TipoVerde() => 'Verde',
  TipoAzul() => 'Azul',
  TipoMorado() => 'Morado',
  TipoBlanco() => 'Blanco',
  TipoNaranja(:final minimo, :final maximo) => 'Naranja $minimo-$maximo',
};

/// Una zona del tablero: su tipo, las casillas que la forman y los puntos
/// para el 1.º, 2.º y 3.º jugador que la llenen.
class ZonaDef {
  final String nombre;
  final Tipo tipo;
  final List<(int, int)> celdas;
  final List<int> puntos;

  const ZonaDef({
    required this.nombre,
    required this.tipo,
    required this.celdas,
    required this.puntos,
  });
}

/// Movimientos permitidos: arriba, abajo, izquierda y derecha (sin diagonales).
const List<(int, int)> direccionesVecinas = [(1, 0), (-1, 0), (0, 1), (0, -1)];

/// Todas las zonas del tablero y a qué zona pertenece cada casilla.
class EstructuraTablero {
  final List<ZonaDef> zonas;
  final List<List<int>> indiceZona;

  const EstructuraTablero(this.zonas, this.indiceZona);

  /// Agrupa las casillas vecinas (arriba, abajo, izquierda, derecha) del
  /// mismo tipo en una zona. Los tipos de [zonaUnica] son la excepción:
  /// todas sus casillas forman una sola zona aunque estén separadas.
  /// [puntos] da los puntos (1.º, 2.º, 3.º) de cada tipo del mapa; si falta
  /// algún tipo del layout, lanza un ArgumentError.
  factory EstructuraTablero.desdeLayout(
    List<List<Tipo>> layout, {
    Set<Tipo> zonaUnica = const {Tipo.amarillo},
    required Map<Tipo, List<int>> puntos,
  }) {
    final filas = layout.length;
    final columnas = layout[0].length;
    final indice = List.generate(filas, (_) => List.filled(columnas, -1));
    final grupos = <(Tipo, List<(int, int)>)>[];

    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        if (indice[f][c] != -1) continue;

        final tipo = layout[f][c];
        final idx = grupos.length;
        final celdas = <(int, int)>[];

        if (zonaUnica.contains(tipo)) {
          for (var ff = 0; ff < filas; ff++) {
            for (var cc = 0; cc < columnas; cc++) {
              if (layout[ff][cc] == tipo) {
                indice[ff][cc] = idx;
                celdas.add((ff, cc));
              }
            }
          }
        } else {
          final pendientes = <(int, int)>[(f, c)];
          indice[f][c] = idx;
          while (pendientes.isNotEmpty) {
            final (actualF, actualC) = pendientes.removeLast();
            celdas.add((actualF, actualC));
            for (final (df, dc) in direccionesVecinas) {
              final nf = actualF + df;
              final nc = actualC + dc;
              if (nf < 0 || nf >= filas || nc < 0 || nc >= columnas) continue;
              if (indice[nf][nc] != -1 || layout[nf][nc] != tipo) continue;
              indice[nf][nc] = idx;
              pendientes.add((nf, nc));
            }
          }
        }

        grupos.add((tipo, celdas));
      }
    }

    // Se numera solo si hay más de una zona del mismo tipo.
    final total = <Tipo, int>{};
    for (final (tipo, _) in grupos) {
      total[tipo] = (total[tipo] ?? 0) + 1;
    }
    final contador = <Tipo, int>{};
    final zonas = <ZonaDef>[];
    for (final (tipo, celdas) in grupos) {
      final numero = (contador[tipo] ?? 0) + 1;
      contador[tipo] = numero;
      zonas.add(
        ZonaDef(
          nombre: total[tipo] == 1
              ? nombreDe(tipo)
              : '${nombreDe(tipo)} $numero',
          tipo: tipo,
          celdas: celdas,
          puntos:
              puntos[tipo] ??
              (throw ArgumentError('Faltan los puntos de ${nombreDe(tipo)}')),
        ),
      );
    }
    return EstructuraTablero(zonas, indice);
  }
}

/// Un mapa del juego (en pantalla se muestra como "Mapa N").
class Nivel {
  final int numero;
  final List<List<Tipo>> layout;

  /// Las 6 casillas con estrella, en orden de lectura (fila por fila).
  final List<PosicionCasilla> estrellas;

  /// Las zonas del mapa, armadas una sola vez.
  final EstructuraTablero estructura;

  Nivel({
    required this.numero,
    required this.layout,
    required this.estrellas,
    required Set<Tipo> zonaUnica,
    required Map<Tipo, List<int>> puntos,
  }) : estructura = EstructuraTablero.desdeLayout(
         layout,
         zonaUnica: zonaUnica,
         puntos: puntos,
       );

  bool esEstrella(int fila, int columna) =>
      estrellas.any((p) => p.fila == fila && p.columna == columna);
}

final Nivel nivel1 = Nivel(
  numero: 1,
  layout: layoutTableroNivel1,
  estrellas: casillasEstrella,
  zonaUnica: {Tipo.amarillo},
  puntos: {
    Tipo.azul: [7, 5, 3],
    Tipo.verde: [4, 3, 2],
    Tipo.rojo: [6, 4, 2],
    Tipo.morado: [6, 4, 2],
    Tipo.amarillo: [8, 6, 4],
  },
);

final Nivel nivel2 = Nivel(
  numero: 2,
  layout: layoutTableroNivel2,
  estrellas: casillasEstrellaNivel2,
  zonaUnica: {Tipo.amarillo, Tipo.blanco},
  puntos: {
    Tipo.azul: [7, 5, 3],
    Tipo.verde: [4, 3, 2],
    Tipo.rojo: [6, 4, 2],
    Tipo.morado: [6, 4, 2],
    Tipo.amarillo: [6, 4, 2],
    Tipo.blanco: [3, 2, 1],
  },
);

final Nivel nivel3 = Nivel(
  numero: 3,
  layout: layoutTableroNivel3,
  estrellas: casillasEstrellaNivel3,
  zonaUnica: {Tipo.blanco},
  puntos: {
    Tipo.azul: [7, 5, 3],
    Tipo.verde: [6, 5, 4],
    Tipo.rojo: [6, 4, 2],
    Tipo.morado: [7, 5, 3],
    Tipo.amarillo: [7, 5, 3],
    Tipo.blanco: [8, 6, 4],
  },
);

final Nivel nivel4 = Nivel(
  numero: 4,
  layout: layoutTableroNivel4,
  estrellas: casillasEstrellaNivel4,
  zonaUnica: {Tipo.amarillo, Tipo.azul, Tipo.verde},
  puntos: {
    Tipo.azul: [8, 6, 4],
    Tipo.verde: [3, 2, 1],
    Tipo.rojo: [6, 4, 2],
    Tipo.morado: [7, 5, 3],
    Tipo.amarillo: [8, 6, 4],
    Tipo.naranja46: [6, 4, 3],
    Tipo.naranja13: [6, 4, 3],
  },
);

/// Los mapas que se pueden elegir, en orden.
final List<Nivel> nivelesDisponibles = [nivel1, nivel2, nivel3, nivel4];

/// El mapa con ese [numero], o null si no existe.
Nivel? nivelPorNumero(int numero) {
  for (final mapa in nivelesDisponibles) {
    if (mapa.numero == numero) return mapa;
  }
  return null;
}
