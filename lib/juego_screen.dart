import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'juego.dart';
import 'juego_cubit.dart';
import 'reglas.dart';
import 'tipo.dart';

const _fondo = Color(0xFF14162B);
const _panel = Color(0xFF1F2244);
const _dorado = Color(0xFFFFD166);

class JuegoScreen extends StatelessWidget {
  /// Los 6 números iniciales de cada jugador.
  final List<List<int>> iniciales;

  /// Mapa que se juega (por defecto el 1).
  final Nivel? nivel;

  const JuegoScreen({super.key, required this.iniciales, this.nivel});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => JuegoCubit(iniciales: iniciales, nivel: nivel),
      child: const _VistaJuego(),
    );
  }
}

class _VistaJuego extends StatelessWidget {
  const _VistaJuego();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: SafeArea(
        child: BlocConsumer<JuegoCubit, JuegoEstado>(
          listenWhen: (anterior, actual) =>
              !anterior.terminado && actual.terminado,
          listener: (context, estado) => _mostrarFinal(context, estado),
          builder: (context, estado) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: Column(
                    children: [
                      _Encabezado(estado: estado),
                      const SizedBox(height: 4),
                      _Marcadores(estado: estado),
                      const SizedBox(height: 8),
                      _ZonaDados(estado: estado),
                      const SizedBox(height: 8),
                      Expanded(child: _TableroJuego(estado: estado)),
                      const SizedBox(height: 8),
                      _PanelZonas(estado: estado),
                      const SizedBox(height: 8),
                      _Botones(estado: estado),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _mostrarFinal(BuildContext context, JuegoEstado estado) {
    final n = estado.totalJugadores;
    final puntajes = [for (var p = 0; p < n; p++) estado.puntajeDe(p)];
    final maximo = puntajes.reduce(max);
    final ganadores = [
      for (var p = 0; p < n; p++)
        if (puntajes[p] == maximo) p + 1,
    ];
    final orden = List.generate(n, (i) => i)
      ..sort((a, b) => puntajes[b].compareTo(puntajes[a]));

    final titulo = n == 1
        ? 'Partida terminada'
        : ganadores.length == 1
            ? 'Gana el Jugador ${ganadores.first}'
            : 'Empate entre los jugadores ${ganadores.join(', ')}';

    final lineas = <Widget>[
      if (n == 1)
        Text('Puntaje final: ${puntajes[0]} puntos')
      else
        for (final p in orden) Text('Jugador ${p + 1}: ${puntajes[p]} puntos'),
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lineas,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Ver tablero'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).popUntil((r) => r.isFirst),
            child: const Text('Nueva partida'),
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final JuegoEstado estado;

  const _Encabezado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final turno = estado.terminado
        ? 'Partida terminada'
        : estado.esIndividual
            ? 'Turno ${estado.turno}'
            : 'Turno: Jugador ${estado.jugador + 1}';

    return Row(
      children: [
        // En pantallas angostas (320 px) el título se achica para caber.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BRILLIANT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Mapa ${estado.nivel.numero}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                turno,
                style: const TextStyle(
                  color: _dorado,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => mostrarReglas(context),
          tooltip: 'Reglas',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
        ),
      ],
    );
  }
}

class _Marcadores extends StatelessWidget {
  final JuegoEstado estado;

  const _Marcadores({required this.estado});

  @override
  Widget build(BuildContext context) {
    final n = estado.totalJugadores;
    return Row(
      children: [
        for (var p = 0; p < n; p++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: p == n - 1 ? 0 : 6),
              child: _Marcador(
                nombre: n == 1 ? 'PUNTOS' : 'JUGADOR ${p + 1}',
                puntos: estado.puntajeDe(p),
                activo: n > 1 && p == estado.jugador && !estado.terminado,
              ),
            ),
          ),
      ],
    );
  }
}

class _Marcador extends StatelessWidget {
  final String nombre;
  final int puntos;
  final bool activo;

  const _Marcador({
    required this.nombre,
    required this.puntos,
    required this.activo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activo ? _dorado : Colors.transparent,
          width: 2,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nombre,
                style: TextStyle(
                  color: activo ? _dorado : Colors.white70,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$puntos',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZonaDados extends StatelessWidget {
  final JuegoEstado estado;

  const _ZonaDados({required this.estado});

  String get _instruccion {
    if (estado.terminado) return 'Partida terminada';
    if (!estado.hayDados) {
      return estado.esIndividual
          ? 'Tira los dados para empezar el turno'
          : 'Jugador ${estado.jugador + 1}, tira los dados';
    }
    if (estado.ancla == null) {
      return estado.hayJugadas
          ? 'Toca un dado para elegirlo como ancla'
          : 'No hay jugadas posibles con estos dados';
    }
    if (estado.jugadasResaltadas.isEmpty) {
      return 'Con ese ancla no hay lugar, prueba con el otro dado';
    }
    return 'Coloca el ${estado.aColocar} junto a un ${estado.ancla} '
        '(casillas iluminadas)';
  }

  String _etiqueta(int indice) {
    if (estado.indiceAncla == null) return '';
    return estado.indiceAncla == indice ? 'ANCLA' : 'A COLOCAR';
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<JuegoCubit>();

    return SizedBox(
      height: 76,
      child: Row(
        children: [
          _Dado(
            key: const Key('dado-0'),
            valor: estado.dado1,
            etiqueta: _etiqueta(0),
            esAncla: estado.indiceAncla == 0,
            onTap: estado.terminado || !estado.hayDados
                ? null
                : () => cubit.elegirAncla(0),
          ),
          const SizedBox(width: 10),
          _Dado(
            key: const Key('dado-1'),
            valor: estado.dado2,
            etiqueta: _etiqueta(1),
            esAncla: estado.indiceAncla == 1,
            onTap: estado.terminado || !estado.hayDados
                ? null
                : () => cubit.elegirAncla(1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _instruccion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (estado.mensaje.isNotEmpty)
                  Text(
                    estado.mensaje,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _dorado,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dado extends StatelessWidget {
  final int? valor;
  final String etiqueta;
  final bool esAncla;
  final VoidCallback? onTap;

  const _Dado({
    super.key,
    required this.valor,
    required this.etiqueta,
    required this.esAncla,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
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

/// El tablero ocupa el espacio que sobra, como un cuadrado.
class _TableroJuego extends StatelessWidget {
  final JuegoEstado estado;

  const _TableroJuego({required this.estado});

  @override
  Widget build(BuildContext context) {
    final resaltadas = estado.jugadasResaltadas;
    final ancla = estado.ancla;
    final tablero = estado.juego.tablero;
    final mapa = estado.nivel;
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
                            child: _CeldaJuego(
                              key: Key('celda-$f-$col'),
                              tipo: layout[f][col],
                              valor: tablero[f][col],
                              resaltada: resaltadas.contains((f, col)),
                              esAncla:
                                  ancla != null && tablero[f][col] == ancla,
                              esSemilla: mapa.esEstrella(f, col),
                              sugerido: estado.aColocar,
                              onTap: resaltadas.contains((f, col))
                                  ? () => context
                                      .read<JuegoCubit>()
                                      .colocar(f, col)
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

class _CeldaJuego extends StatelessWidget {
  final Tipo tipo;
  final int? valor;
  final bool resaltada;
  final bool esAncla;
  final bool esSemilla;
  final int? sugerido;
  final VoidCallback? onTap;

  const _CeldaJuego({
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
class _PanelZonas extends StatelessWidget {
  final JuegoEstado estado;

  const _PanelZonas({required this.estado});

  @override
  Widget build(BuildContext context) {
    final zonas = estado.nivel.estructura.zonas;

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
                child: _ChipZona(
                  zona: zonas[i],
                  orden: estado.ordenZonas[i],
                  individual: estado.esIndividual,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChipZona extends StatelessWidget {
  final ZonaDef zona;
  final List<int> orden; // jugadores que la completaron, en orden
  final bool individual;

  const _ChipZona({
    required this.zona,
    required this.orden,
    required this.individual,
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
      detalle = [for (final p in orden) 'J${p + 1}'].join('›');
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

class _Botones extends StatelessWidget {
  final JuegoEstado estado;

  const _Botones({required this.estado});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<JuegoCubit>();

    final String texto;
    final VoidCallback? accion;
    if (estado.terminado) {
      texto = 'Nueva partida';
      accion = () => Navigator.of(context).popUntil((r) => r.isFirst);
    } else if (!estado.hayDados) {
      texto = 'Tirar dados';
      accion = cubit.tirarDados;
    } else if (!estado.hayJugadas) {
      texto = 'Pasar turno';
      accion = cubit.pasarTurno;
    } else {
      texto = 'Elige dado y casilla';
      accion = null;
    }

    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: FilledButton(onPressed: accion, child: Text(texto)),
          ),
          if (!estado.terminado) ...[
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: cubit.terminar,
              child: const Text('Terminar'),
            ),
          ],
        ],
      ),
    );
  }
}