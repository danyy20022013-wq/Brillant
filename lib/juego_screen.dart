import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'juego.dart';
import 'juego_cubit.dart';
import 'tablero_layout.dart';
import 'tipo.dart';

const _fondo = Color(0xFF14162B);
const _panel = Color(0xFF1F2244);
const _dorado = Color(0xFFFFD166);

class JuegoScreen extends StatelessWidget {
  final List<int> iniciales;

  const JuegoScreen({super.key, required this.iniciales});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => JuegoCubit(iniciales: iniciales),
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
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      _Encabezado(estado: estado),
                      const SizedBox(height: 12),
                      _ZonaDados(estado: estado),
                      const SizedBox(height: 16),
                      _TableroJuego(estado: estado),
                      const SizedBox(height: 16),
                      _PanelPuntos(estado: estado),
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Partida terminada'),
        content: Text('Puntaje final: ${estado.juego.puntajeTotal}'),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BRILLIANT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            Text(
              'Turno ${estado.turno}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _dorado, width: 1.5),
          ),
          child: Column(
            children: [
              const Text(
                'PUNTOS',
                style: TextStyle(color: _dorado, fontSize: 11, letterSpacing: 2),
              ),
              Text(
                '${estado.juego.puntajeTotal}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ZonaDados extends StatelessWidget {
  final JuegoEstado estado;

  const _ZonaDados({required this.estado});

  String get _instruccion {
    if (estado.terminado) return 'Partida terminada';
    if (!estado.hayDados) return 'Tira los dados para empezar el turno';
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

    return Column(
      children: [
        if (estado.hayDados)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Dado(
                valor: estado.dado1!,
                etiqueta: _etiqueta(0),
                esAncla: estado.indiceAncla == 0,
                onTap: estado.terminado ? null : () => cubit.elegirAncla(0),
              ),
              const SizedBox(width: 28),
              _Dado(
                valor: estado.dado2!,
                etiqueta: _etiqueta(1),
                esAncla: estado.indiceAncla == 1,
                onTap: estado.terminado ? null : () => cubit.elegirAncla(1),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          _instruccion,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        if (estado.mensaje.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              estado.mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _dorado,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (!estado.terminado && !estado.hayDados)
              FilledButton(
                onPressed: cubit.tirarDados,
                child: const Text('Tirar dados'),
              ),
            if (!estado.terminado && estado.hayDados && !estado.hayJugadas)
              FilledButton(
                onPressed: cubit.pasarTurno,
                child: const Text('Pasar turno'),
              ),
            if (!estado.terminado)
              OutlinedButton(
                onPressed: cubit.terminar,
                child: const Text('Terminar partida'),
              ),
            if (estado.terminado)
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Nueva partida'),
              ),
          ],
        ),
      ],
    );
  }
}

class _Dado extends StatelessWidget {
  final int valor;
  final String etiqueta;
  final bool esAncla;
  final VoidCallback? onTap;

  const _Dado({
    required this.valor,
    required this.etiqueta,
    required this.esAncla,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: esAncla ? _dorado : Colors.transparent,
                width: 4,
              ),
              boxShadow: esAncla
                  ? [
                      BoxShadow(
                        color: _dorado.withValues(alpha: 0.6),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: _Puntos(valor: valor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          etiqueta,
          style: TextStyle(
            color: esAncla ? _dorado : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
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
                              width: 10,
                              height: 10,
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

class _TableroJuego extends StatelessWidget {
  final JuegoEstado estado;

  const _TableroJuego({required this.estado});

  @override
  Widget build(BuildContext context) {
    final resaltadas = estado.jugadasResaltadas;
    final ancla = estado.ancla;

    return AspectRatio(
      aspectRatio: 1,
      child: Column(
        children: [
          for (var f = 0; f < layoutTableroNivel1.length; f++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < layoutTableroNivel1[f].length; c++)
                    Expanded(
                      child: _CeldaJuego(
                        tipo: layoutTableroNivel1[f][c],
                        valor: estado.juego.tablero[f][c],
                        resaltada: resaltadas.contains((f, c)),
                        esAncla: ancla != null &&
                            estado.juego.tablero[f][c] == ancla,
                        esSemilla: Juego.esSemilla(f, c),
                        sugerido: estado.aColocar,
                        onTap: resaltadas.contains((f, c))
                            ? () => context.read<JuegoCubit>().colocar(f, c)
                            : null,
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

class _CeldaJuego extends StatelessWidget {
  final Tipo tipo;
  final int? valor;
  final bool resaltada;
  final bool esAncla;
  final bool esSemilla;
  final int? sugerido;
  final VoidCallback? onTap;

  const _CeldaJuego({
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
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: tipo.color,
            borderRadius: BorderRadius.circular(10),
            border: resaltada
                ? Border.all(color: Colors.white, width: 3)
                : esAncla
                    ? Border.all(color: _dorado, width: 3)
                    : null,
            boxShadow: resaltada
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.7),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Center(
                child: valor != null
                    ? Text(
                        '$valor',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                        ),
                      )
                    : (resaltada && sugerido != null)
                        ? Text(
                            '$sugerido',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
              if (esSemilla)
                const Positioned(
                  right: 2,
                  bottom: 2,
                  child: Icon(Icons.star_rounded, color: _dorado, size: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelPuntos extends StatelessWidget {
  final JuegoEstado estado;

  const _PanelPuntos({required this.estado});

  @override
  Widget build(BuildContext context) {
    final zonas = estructuraNivel1.zonas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Puntos por zona',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.45,
          children: [
            for (var i = 0; i < zonas.length; i++)
              _ChipZona(
                nombre: zonas[i].nombre,
                tipo: zonas[i].tipo,
                puntos: estado.juego.puntos[i],
                completadas: estado.juego.completadas[i],
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Cada zona puntúa solo en sus 3 primeros llenados.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}

class _ChipZona extends StatelessWidget {
  final String nombre;
  final Tipo tipo;
  final int puntos;
  final int completadas;

  const _ChipZona({
    required this.nombre,
    required this.tipo,
    required this.puntos,
    required this.completadas,
  });

  @override
  Widget build(BuildContext context) {
    final tabla = puntosDe(tipo);
    final proximo = completadas < tabla.length ? tabla[completadas] : 0;
    final textoColor = tipo is TipoAmarillo ? Colors.black87 : Colors.white;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tipo.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            nombre,
            style: TextStyle(
              color: textoColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$puntos pts',
            style: TextStyle(
              color: textoColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Llenada ${completadas}x · próx. +$proximo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textoColor, fontSize: 10),
          ),
        ],
      ),
    );
  }
}