import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'juego_screen.dart';
import 'numeros_iniciales_cubit.dart';
import 'reglas.dart';
import 'tablero_layout.dart';
import 'tipo.dart';

const _fondo = Color(0xFF14162B);
const _dorado = Color(0xFFFFD166);

class NumerosInicialesScreen extends StatelessWidget {
  final int jugador;
  final int totalJugadores;
  final List<List<int>> anteriores;

  const NumerosInicialesScreen({
    super.key,
    this.jugador = 1,
    this.totalJugadores = 1,
    this.anteriores = const [],
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NumerosInicialesCubit(),
      child: _Vista(
        jugador: jugador,
        totalJugadores: totalJugadores,
        anteriores: anteriores,
      ),
    );
  }
}

class _Vista extends StatelessWidget {
  final int jugador;
  final int totalJugadores;
  final List<List<int>> anteriores;

  const _Vista({
    required this.jugador,
    required this.totalJugadores,
    required this.anteriores,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: SafeArea(
        child: BlocBuilder<NumerosInicialesCubit, NumerosInicialesEstado>(
          builder: (context, estado) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 48),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'BRILLIANT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 5,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => mostrarReglas(context),
                            tooltip: 'Reglas',
                            icon: const Icon(
                              Icons.help_outline_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      if (totalJugadores > 1)
                        Text(
                          'Jugador $jugador de $totalJugadores',
                          style: const TextStyle(
                            color: _dorado,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const Text(
                        'Toca una ⭐ y elige su número (1 al 6, sin repetir)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Expanded(child: _Grilla(estado: estado)),
                      SizedBox(
                        height: 24,
                        child: Center(
                          child: estado.tieneRepetidos
                              ? const Text(
                                  'Los números no pueden repetirse',
                                  style: TextStyle(color: Color(0xFFFF6B6B)),
                                )
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: estado.esValido
                              ? () => _iniciar(context, estado)
                              : null,
                          child: const Text('Inicio'),
                        ),
                      ),
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

  void _iniciar(BuildContext context, NumerosInicialesEstado estado) {
    final iniciales = estado.valores.whereType<int>().toList();
    final todos = [...anteriores, iniciales];
    final navigator = Navigator.of(context);

    if (jugador < totalJugadores) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => NumerosInicialesScreen(
            jugador: jugador + 1,
            totalJugadores: totalJugadores,
            anteriores: todos,
          ),
        ),
      );
    } else {
      navigator.push(
        MaterialPageRoute(builder: (_) => JuegoScreen(iniciales: todos)),
      );
    }
  }
}

/// El tablero ocupa el espacio que sobra, como un cuadrado.
class _Grilla extends StatelessWidget {
  final NumerosInicialesEstado estado;

  const _Grilla({required this.estado});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final lado = max(0.0, min(c.maxWidth, c.maxHeight));
        return Center(
          child: SizedBox(
            width: lado,
            height: lado,
            child: Column(
              children: [
                for (var f = 0; f < layoutTableroNivel1.length; f++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0;
                            col < layoutTableroNivel1[f].length;
                            col++)
                          Expanded(child: _celda(f, col)),
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

  Widget _celda(int fila, int columna) {
    int? indice;
    for (var i = 0; i < casillasEstrella.length; i++) {
      if (casillasEstrella[i].fila == fila &&
          casillasEstrella[i].columna == columna) {
        indice = i;
      }
    }
    return _Casilla(
      tipo: layoutTableroNivel1[fila][columna],
      indice: indice,
      valor: indice == null ? null : estado.valores[indice],
      repetida: indice != null && estado.casillaRepetida(indice),
    );
  }
}

class _Casilla extends StatelessWidget {
  final Tipo tipo;
  final int? indice;
  final int? valor;
  final bool repetida;

  const _Casilla({
    required this.tipo,
    required this.indice,
    required this.valor,
    required this.repetida,
  });

  @override
  Widget build(BuildContext context) {
    final esEstrella = indice != null;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: esEstrella ? () => _elegir(context) : null,
        child: Container(
          decoration: BoxDecoration(
            color: tipo.color,
            borderRadius: BorderRadius.circular(10),
            border:
                repetida ? Border.all(color: Colors.white, width: 3) : null,
            boxShadow: esEstrella
                ? [
                    BoxShadow(
                      color: tipo.color.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: esEstrella
              ? Center(
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: valor == null
                          ? const Icon(
                              Icons.star_rounded,
                              color: _dorado,
                              size: 22,
                            )
                          : Text(
                              '$valor',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: repetida ? Colors.black : Colors.white,
                              ),
                            ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _elegir(BuildContext context) async {
    final cubit = context.read<NumerosInicialesCubit>();
    final elegido = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1F2244),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Elige un número',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (var n = 1; n <= 6; n++)
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                          backgroundColor: tipo.color,
                        ),
                        onPressed: () => Navigator.of(context).pop(n),
                        child:
                            Text('$n', style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                ],
              ),
              if (valor != null)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(0),
                  child: const Text('Quitar número'),
                ),
            ],
          ),
        ),
      ),
    );

    // null = cerró sin elegir, 0 = quitar el número
    if (elegido != null) {
      cubit.seleccionar(indice!, elegido == 0 ? null : elegido);
    }
  }
}