import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'multijugador_cubit.dart';

const _panel = Color(0xFF1F2244);
const _dorado = Color(0xFFFFD166);
const _rojo = Color(0xFFFF8A8A);

/// Título del resultado según las posiciones del servidor.
String tituloResultado(
  List<PosicionRemota> resultado,
  int? miId,
  String Function(int id) nombre,
) {
  final primeros = resultado.where((r) => r.posicion == 1).toList();
  if (primeros.length > 1) {
    return 'Empate: ${primeros.map((r) => nombre(r.id)).join(' y ')}';
  }
  if (primeros.isEmpty) return 'Partida terminada';
  if (primeros.first.id == miId) return '¡Ganaste!';
  return 'Gana ${nombre(primeros.first.id)}';
}

/// Resultado final: posiciones, puntajes, empates y quién se rindió o
/// abandonó (quedan últimos sin importar sus puntos).
class VistaResultado extends StatelessWidget {
  final EstadoMultijugador estado;

  const VistaResultado({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final sala = estado.sala!;
    final resultado = sala.resultado ?? const <PosicionRemota>[];
    final empatados = <int, int>{};
    for (final r in resultado) {
      empatados[r.posicion] = (empatados[r.posicion] ?? 0) + 1;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.emoji_events_rounded, color: _dorado, size: 48),
              const SizedBox(height: 6),
              Text(
                tituloResultado(resultado, estado.miId, sala.nombreDe),
                key: const Key('titulo-resultado'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Mapa ${sala.mapa}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 16),
              for (final r in resultado)
                Container(
                  key: Key('resultado-${r.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: r.id == estado.miId
                          ? _dorado.withValues(alpha: 0.7)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${r.posicion}.º',
                          style: TextStyle(
                            color: r.posicion == 1 ? _dorado : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.id == estado.miId
                                  ? '${sala.nombreDe(r.id)} (tú)'
                                  : sala.nombreDe(r.id),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (r.rendido)
                              const Text(
                                'Se rindió',
                                style: TextStyle(color: _rojo, fontSize: 12),
                              )
                            else if (r.abandono)
                              const Text(
                                'Abandonó',
                                style: TextStyle(color: _rojo, fontSize: 12),
                              )
                            else if ((empatados[r.posicion] ?? 0) > 1)
                              const Text(
                                'Empate',
                                style: TextStyle(color: _dorado, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${r.puntaje} pts',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: FilledButton(
                  key: const Key('volver-menu'),
                  onPressed: () => context.read<MultijugadorCubit>().salir(),
                  child: const Text('Volver al menú'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
