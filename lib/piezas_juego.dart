import 'dart:math';

import 'package:flutter/material.dart';

import 'tipo.dart';

/// Piezas visuales de la partida que comparten el modo individual y el
/// multijugador: dado, tablero, chips de zona y aviso flotante. No conocen
/// ningún cubit: reciben los datos y avisan con callbacks.

const _fondo = Color(0xFF14162B);
const _panel = Color(0xFF1F2244);
const _dorado = Color(0xFFFFD166);

/// Duración del giro de los dados. Solo es visual: el valor lo decide el
/// cubit (individual) o el servidor (multijugador).
const duracionGiroDados = Duration(milliseconds: 500);

/// Cuánto se queda en pantalla el aviso de zona completada.
const duracionAvisoZona = Duration(seconds: 3);

/// Cara que muestra el dado [indice] mientras gira (cambia con [giro]).
int caraEnGiro(double giro, int indice) =>
    ((giro * 12).floor() + indice * 3) % 6 + 1;

/// Muestra un aviso flotante sobre el panel de zonas (no tapa el tablero,
/// los dados ni los botones) que se va solo.
void mostrarAvisoFlotante(
  BuildContext context, {
  required Key clave,
  required String titulo,
  required String detalle,
  required Color color,
  bool destacado = true,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      key: clave,
      behavior: SnackBarBehavior.floating,
      duration: duracionAvisoZona,
      backgroundColor: _panel,
      elevation: 6,
      // Queda justo encima de los botones de abajo, sobre el panel de zonas,
      // y es bajo para no tapar el tablero en celulares chicos.
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 66),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color, width: 3),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: destacado ? _dorado : Colors.white70,
              fontSize: destacado ? 22 : 18,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          Text(
            detalle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

/// Un dado. Con [valor] null muestra "?".
class CaraDado extends StatelessWidget {
  final int? valor;
  final String etiqueta;
  final bool esAncla;
  final VoidCallback? onTap;

  /// Giro del dado en radianes (0 cuando está quieto).
  final double angulo;

  const CaraDado({
    super.key,
    required this.valor,
    required this.etiqueta,
    required this.esAncla,
    required this.onTap,
    this.angulo = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Transform.rotate(
            angle: angulo,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: valor == null ? 0.25 : 1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: esAncla ? _dorado : Colors.transparent,
                  width: 3,
                ),
                boxShadow: esAncla
                    ? [
                        BoxShadow(
                          color: _dorado.withValues(alpha: 0.6),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: valor == null
                  ? const Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : _Puntos(valor: valor!),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          etiqueta,
          style: TextStyle(
            color: esAncla ? _dorado : Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Dibuja los puntitos de la cara del dado en una grilla de 3x3.
class _Puntos extends StatelessWidget {
  final int valor;

  const _Puntos({required this.valor});

  static const Map<int, List<int>> _caras = {
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final activos = _caras[valor] ?? const <int>[];
    return Column(
      children: [
        for (var fila = 0; fila < 3; fila++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 3; col++)
                  Expanded(
                    child: Center(
                      child: activos.contains(fila * 3 + col)
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _fondo,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// El tablero de un jugador: ocupa el espacio que sobra, como un cuadrado.
class TableroPartida extends StatelessWidget {
  final Nivel mapa;
  final List<List<int?>> tablero;

  /// Casillas iluminadas (donde se puede colocar).
  final Set<(int, int)> resaltadas;

  /// Número ancla (sus casillas se marcan) y número a colocar (se sugiere
  /// en las iluminadas).
  final int? ancla;
  final int? sugerido;

  /// Se llama al tocar una casilla iluminada.
  final void Function(int fila, int columna)? alTocar;

  const TableroPartida({
    super.key,
    required this.mapa,
    required this.tablero,
    this.resaltadas = const {},
    this.ancla,
    this.sugerido,
    this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final layout = mapa.layout;
    return LayoutBuilder(
      builder: (context, c) {
        final lado = max(0.0, min(c.maxWidth, c.maxHeight));
        return Center(
          child: SizedBox(
            width: lado,
            height: lado,
            child: Column(
              children: [
                for (var f = 0; f < layout.length; f++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < layout[f].length; col++)
                          Expanded(
                            child: CeldaPartida(
                              key: Key('celda-$f-$col'),
                              tipo: layout[f][col],
                              valor: tablero[f][col],
                              resaltada: resaltadas.contains((f, col)),
                              esAncla:
                                  ancla != null && tablero[f][col] == ancla,
                              esSemilla: mapa.esEstrella(f, col),
                              sugerido: sugerido,
                              onTap:
                                  alTocar != null &&
                                      resaltadas.contains((f, col))
                                  ? () => alTocar!(f, col)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CeldaPartida extends StatelessWidget {
  final Tipo tipo;
  final int? valor;
  final bool resaltada;
  final bool esAncla;
  final bool esSemilla;
  final int? sugerido;
  final VoidCallback? onTap;

  const CeldaPartida({
    super.key,
    required this.tipo,
    required this.valor,
    required this.resaltada,
    required this.esAncla,
    required this.esSemilla,
    required this.sugerido,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textoOscuro = tipo is TipoBlanco;

    Widget? texto;
    if (valor != null) {
      texto = Text(
        '$valor',
        style: TextStyle(
          color: textoOscuro ? Colors.black87 : Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          shadows: textoOscuro
              ? null
              : const [Shadow(blurRadius: 2, color: Colors.black54)],
        ),
      );
    } else if (resaltada && sugerido != null) {
      texto = Text(
        '$sugerido',
        style: TextStyle(
          color: textoOscuro ? Colors.black54 : Colors.white70,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: tipo.color,
            borderRadius: BorderRadius.circular(8),
            border: resaltada
                ? Border.all(color: Colors.white, width: 2.5)
                : esAncla
                ? Border.all(color: _dorado, width: 2.5)
                : null,
            boxShadow: resaltada
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.7),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              if (texto != null)
                Center(
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: texto,
                    ),
                  ),
                ),
              if (esSemilla)
                const Positioned(
                  right: 1,
                  bottom: 1,
                  child: Icon(Icons.star_rounded, color: _dorado, size: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Las zonas del mapa en filas de chips, con su próximo puntaje.
/// [etiqueta] dice cómo nombrar a cada jugador que completó una zona.
class PanelZonas extends StatelessWidget {
  final Nivel mapa;

  /// Por cada zona, los jugadores que la completaron, en orden.
  final List<List<int>> ordenZonas;
  final bool individual;
  final String Function(int jugador) etiqueta;

  const PanelZonas({
    super.key,
    required this.mapa,
    required this.ordenZonas,
    required this.individual,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    final zonas = mapa.estructura.zonas;

    return LayoutBuilder(
      builder: (context, c) {
        const espacio = 6.0;
        final ancho = (c.maxWidth - espacio * 4 - 1) / 5;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (var i = 0; i < zonas.length; i++)
              SizedBox(
                width: ancho,
                height: 40,
                child: ChipZona(
                  zona: zonas[i],
                  orden: i < ordenZonas.length ? ordenZonas[i] : const [],
                  individual: individual,
                  etiqueta: etiqueta,
                ),
              ),
          ],
        );
      },
    );
  }
}

class ChipZona extends StatelessWidget {
  final ZonaDef zona;
  final List<int> orden; // jugadores que la completaron, en orden
  final bool individual;
  final String Function(int jugador) etiqueta;

  const ChipZona({
    super.key,
    required this.zona,
    required this.orden,
    required this.individual,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    final tabla = zona.puntos;
    final proximo = orden.length < tabla.length ? tabla[orden.length] : 0;
    final oscuro = zona.tipo is TipoAmarillo || zona.tipo is TipoBlanco;
    final color = oscuro ? Colors.black87 : Colors.white;

    final String detalle;
    if (orden.isEmpty) {
      detalle = '+$proximo';
    } else if (individual) {
      detalle = '✓';
    } else {
      detalle = [for (final p in orden) etiqueta(p)].join('›');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: zona.tipo.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              zona.nombre,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              detalle,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vista previa del mapa; las estrellas se ven como puntos dorados.
class MiniTablero extends StatelessWidget {
  final Nivel mapa;

  const MiniTablero({super.key, required this.mapa});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var f = 0; f < mapa.layout.length; f++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < mapa.layout[f].length; c++)
                  Expanded(
                    child: Container(
                      key: Key('mini-${mapa.numero}-$f-$c'),
                      margin: const EdgeInsets.all(0.8),
                      decoration: BoxDecoration(
                        color: mapa.layout[f][c].color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: mapa.esEstrella(f, c)
                          ? const Center(
                              child: FractionallySizedBox(
                                widthFactor: 0.45,
                                heightFactor: 0.45,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _dorado,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
