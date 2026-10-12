import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'numeros_iniciales_cubit.dart';
import 'tablero_layout.dart';
import 'tipo.dart';

const _fondo = Color(0xFF14162B);
const _dorado = Color(0xFFFFD166);

class NumerosInicialesScreen extends StatelessWidget {
  const NumerosInicialesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NumerosInicialesCubit(),
      child: const _Vista(),
    );
  }
}

class _Vista extends StatelessWidget {
  const _Vista();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: SafeArea(
        child: BlocBuilder<NumerosInicialesCubit, NumerosInicialesEstado>(
          builder: (context, estado) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'BRILLIANT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Elige tus 6 números iniciales (del 1 al 6)',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _Grilla(estado: estado),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 24,
                    child: estado.tieneRepetidos
                        ? const Text(
                            'Los números no pueden repetirse',
                            style: TextStyle(color: Color(0xFFFF6B6B)),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: estado.esValido
                          ? () => _iniciar(context)
                          : null,
                      child: const Text('Inicio'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _iniciar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Números iniciales válidos. ¡A jugar!')),
    );
  }
}

class _Grilla extends StatelessWidget {
  final NumerosInicialesEstado estado;

  const _Grilla({required this.estado});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var f = 0; f < layoutTableroNivel1.length; f++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < layoutTableroNivel1[f].length; c++)
                  Expanded(child: _celda(f, c)),
              ],
            ),
          ),
      ],
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
      padding: const EdgeInsets.all(2.5),
      child: GestureDetector(
        onTap: esEstrella ? () => _elegir(context) : null,
        child: Container(
          decoration: BoxDecoration(
            color: tipo.color,
            borderRadius: BorderRadius.circular(12),
            border: repetida
                ? Border.all(color: Colors.white, width: 3)
                : null,
            boxShadow: esEstrella
                ? [BoxShadow(color: tipo.color.withValues(alpha: 0.6), blurRadius: 8)]
                : null,
          ),
          child: esEstrella
              ? Center(
                  child: valor == null
                      ? const Icon(Icons.star_rounded, color: _dorado, size: 22)
                      : Text(
                          '$valor',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: repetida ? Colors.black : Colors.white,
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
      builder: (_) => Padding(
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
                      child: Text('$n', style: const TextStyle(fontSize: 18)),
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
    );

    // null = cerró sin elegir, 0 = quitar el número
    if (elegido != null) {
      cubit.seleccionar(indice!, elegido == 0 ? null : elegido);
    }
  }
}