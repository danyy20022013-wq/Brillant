import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../piezas_juego.dart';
import 'cuenta_regresiva.dart';
import 'multijugador_cubit.dart';

const _panel = Color(0xFF1F2244);
const _dorado = Color(0xFFFFD166);
const _verde = Color(0xFF3FB67A);
const _rojo = Color(0xFFFF8A8A);

/// Texto para invitar a alguien a la sala.
String textoInvitacion(String codigo) =>
    '¡Juega Brilliant conmigo! Abre la app, toca "Unirme con código" en '
    'Buscar partida y escribe: $codigo';

/// Pide confirmación antes de salir de la sala.
Future<bool> confirmarSalirDeSala(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('¿Salir de la sala?'),
      content: const Text(
        'Dejarás tu lugar en la sala. Si quieres volver, tendrás que unirte '
        'otra vez con el código (si todavía hay lugar).',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirmar-salir-sala'),
          onPressed: () => Navigator.of(dialogo).pop(true),
          child: const Text('Salir'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// La sala antes de empezar. Todo lo que muestra viene del servidor.
class VistaLobby extends StatelessWidget {
  final EstadoMultijugador estado;

  const VistaLobby({super.key, required this.estado});

  Future<void> _copiar(BuildContext context, String texto, String aviso) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(aviso)));
  }

  Future<void> _salir(BuildContext context) async {
    final cubit = context.read<MultijugadorCubit>();
    if (await confirmarSalirDeSala(context)) cubit.salir();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MultijugadorCubit>();
    final sala = estado.sala!;
    final yo = estado.yo;
    final presentes = sala.presentes;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('lobby-salir'),
                onPressed: () => _salir(context),
                tooltip: 'Salir de la sala',
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
              const Expanded(
                child: Text(
                  'Sala de espera',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Código de la sala',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SelectableText(
              sala.codigo,
              key: const Key('codigo-sala'),
              style: const TextStyle(
                color: _dorado,
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('copiar-codigo'),
                onPressed: () =>
                    _copiar(context, sala.codigo, 'Código copiado'),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copiar'),
              ),
              OutlinedButton.icon(
                key: const Key('compartir-codigo'),
                onPressed: () => _copiar(
                  context,
                  textoInvitacion(sala.codigo),
                  'Invitación copiada: pégala donde quieras compartirla',
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Compartir'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: MiniTablero(mapa: sala.nivel),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mapa ${sala.mapa}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${presentes.length} de ${sala.maximo} jugadores',
                        key: const Key('lobby-cupo'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (sala.segundosParaCaducar case final segundos?)
                        CuentaRegresiva(
                          key: const Key('lobby-caduca'),
                          total: Duration(seconds: segundos),
                          desde: estado.recibida ?? cubit.ahora(),
                          reloj: cubit.ahora,
                          constructor: (_, s) => Text(
                            'La sala se cierra en ${formatoSegundos(s)} si '
                            'no empieza',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final j in presentes)
            _FilaJugador(jugador: j, esYo: j.id == estado.miId),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.tonal(
              key: const Key('boton-listo'),
              onPressed: yo == null ? null : () => cubit.listo(!yo.listo),
              child: Text(
                yo?.listo ?? false ? 'Ya no estoy listo' : 'Estoy listo',
              ),
            ),
          ),
          if (estado.soyAnfitrion) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const Key('boton-iniciar'),
                onPressed: sala.sePuedeIniciar ? cubit.iniciar : null,
                child: const Text('Iniciar partida'),
              ),
            ),
            if (!sala.sePuedeIniciar)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Para iniciar hacen falta 2 o más jugadores y que todos '
                  'estén listos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'El anfitrión inicia la partida cuando todos estén listos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('boton-salir-sala'),
            onPressed: () => _salir(context),
            style: TextButton.styleFrom(foregroundColor: _rojo),
            child: const Text('Salir de la sala'),
          ),
        ],
      ),
    );
  }
}

class _FilaJugador extends StatelessWidget {
  final JugadorRemoto jugador;
  final bool esYo;

  const _FilaJugador({required this.jugador, required this.esYo});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('lobby-jugador-${jugador.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esYo ? _dorado.withValues(alpha: 0.6) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            jugador.anfitrion ? Icons.star_rounded : Icons.person_rounded,
            color: jugador.anfitrion ? _dorado : Colors.white54,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esYo ? '${jugador.nombre} (tú)' : jugador.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (jugador.anfitrion)
                      const Text(
                        'Anfitrión',
                        style: TextStyle(color: _dorado, fontSize: 12),
                      ),
                    if (!jugador.conectado)
                      const Text(
                        'Desconectado',
                        style: TextStyle(color: _rojo, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: jugador.listo
                  ? _verde.withValues(alpha: 0.25)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              jugador.listo ? 'Listo' : 'No listo',
              style: TextStyle(
                color: jugador.listo ? _verde : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
