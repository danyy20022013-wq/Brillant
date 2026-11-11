import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../numeros_iniciales_screen.dart';
import 'cuenta_regresiva.dart';
import 'multijugador_cubit.dart';

const _panel = Color(0xFF1F2244);
const _dorado = Color(0xFFFFD166);
const _verde = Color(0xFF3FB67A);

/// Elegir los números iniciales con el tiempo visible. Reutiliza la
/// pantalla de siempre; al confirmar, los manda al servidor.
class VistaNumerosMulti extends StatelessWidget {
  final EstadoMultijugador estado;

  const VistaNumerosMulti({super.key, required this.estado});

  Widget _tiempo(BuildContext context) {
    final cubit = context.read<MultijugadorCubit>();
    final segundos = estado.sala?.segundosParaNumeros;
    if (segundos == null) return const SizedBox.shrink();
    return CuentaRegresiva(
      key: const Key('tiempo-numeros'),
      total: Duration(seconds: segundos),
      desde: estado.recibida ?? cubit.ahora(),
      reloj: cubit.ahora,
      constructor: (_, s) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '⏱ $s s para elegir. Si no alcanzas, el servidor elige por ti.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: s <= 15 ? const Color(0xFFFF8A8A) : _dorado,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sala = estado.sala!;
    final yo = estado.yo;
    if (yo != null && yo.sigueJugando && !yo.numerosEnviados) {
      return NumerosInicialesScreen(
        nivel: sala.nivel,
        alConfirmar: context.read<MultijugadorCubit>().enviarNumeros,
        encabezado: _tiempo(context),
      );
    }

    // Ya los mandé: espero a los demás.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.hourglass_top_rounded, color: _dorado, size: 40),
            const SizedBox(height: 8),
            const Text(
              'Esperando a los demás',
              key: Key('esperando-numeros'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            _tiempo(context),
            const SizedBox(height: 12),
            for (final j in sala.jugadores)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        j.id == estado.miId ? '${j.nombre} (tú)' : j.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    Text(
                      !j.sigueJugando
                          ? (j.rendido ? 'Se rindió' : 'Abandonó')
                          : j.numerosEnviados
                          ? 'Listo'
                          : 'Eligiendo…',
                      style: TextStyle(
                        color: j.numerosEnviados ? _verde : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
