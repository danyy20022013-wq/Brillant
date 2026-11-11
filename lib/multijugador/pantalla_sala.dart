import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../piezas_juego.dart';
import '../tipo.dart';
import 'multijugador_cubit.dart';
import 'vista_lobby.dart';
import 'vista_numeros_multi.dart';
import 'vista_partida_multi.dart';
import 'vista_resultado.dart';

const _fondo = Color(0xFF14162B);

/// Crea el cubit del multijugador para una acción inicial (crear sala o
/// unirse). La app usa el servidor real; las pruebas, un canal falso.
typedef AbrirSala = MultijugadorCubit Function(AccionInicial accion);

/// Sala en línea: lobby, números iniciales, partida y resultado, según la
/// fase que diga el servidor.
class PantallaSala extends StatelessWidget {
  final MultijugadorCubit Function() crearCubit;

  const PantallaSala({super.key, required this.crearCubit});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = crearCubit();
        unawaited(cubit.conectar());
        return cubit;
      },
      child: const _VistaSala(),
    );
  }
}

class _VistaSala extends StatelessWidget {
  const _VistaSala();

  Future<void> _alFin(BuildContext context, EstadoMultijugador estado) async {
    final navigator = Navigator.of(context);
    final motivo = estado.motivoFin;
    if (motivo != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogo) => AlertDialog(
          title: const Text('Partida en línea'),
          content: Text(motivo, key: const Key('motivo-fin')),
          actions: [
            FilledButton(
              key: const Key('aceptar-fin'),
              onPressed: () => Navigator.of(dialogo).pop(),
              child: const Text('Volver al menú'),
            ),
          ],
        ),
      );
    }
    if (navigator.mounted && navigator.canPop()) navigator.pop();
  }

  void _avisarZona(BuildContext context, SalaRemota sala) {
    final mov = sala.ultimoMovimiento;
    final zona = mov?.zonaCompletada;
    if (mov == null || zona == null) return;
    final zonas = sala.nivel.estructura.zonas;
    final color = zona.zona < zonas.length
        ? zonas[zona.zona].tipo.color
        : Colors.white;
    mostrarAvisoFlotante(
      context,
      clave: Key('aviso-zona-multi-${mov.turno}'),
      titulo: zona.puntos > 0 ? '+${zona.puntos} puntos' : 'Ya no puntúa',
      detalle:
          '${sala.nombreDe(mov.jugador)} completó ${zona.nombre} '
          '(${zona.lugar}.º)',
      color: color,
      destacado: zona.puntos > 0,
    );
  }

  /// Volver con el botón del sistema: en el lobby pregunta si sale; en una
  /// partida en curso, recuerda que hay que rendirse.
  Future<void> _alVolver(BuildContext context) async {
    final cubit = context.read<MultijugadorCubit>();
    final estado = cubit.state;
    final sala = estado.sala;
    final enCurso =
        sala != null &&
        (sala.enNumeros || sala.enTurnos) &&
        (estado.yo?.sigueJugando ?? false);
    if (enCurso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Para dejar la partida usa el botón "Rendirse".'),
        ),
      );
      return;
    }
    if (sala == null || sala.terminada || !(sala.enLobby)) {
      cubit.salir();
      return;
    }
    if (await confirmarSalirDeSala(context)) cubit.salir();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (yaSalio, _) {
        if (!yaSalio) unawaited(_alVolver(context));
      },
      child: Scaffold(
        backgroundColor: _fondo,
        body: SafeArea(
          child: MultiBlocListener(
            listeners: [
              BlocListener<MultijugadorCubit, EstadoMultijugador>(
                listenWhen: (a, b) => !a.fin && b.fin,
                listener: (context, estado) =>
                    unawaited(_alFin(context, estado)),
              ),
              BlocListener<MultijugadorCubit, EstadoMultijugador>(
                listenWhen: (a, b) =>
                    b.error != null && a.numeroError != b.numeroError,
                listener: (context, estado) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        key: const Key('error-multi'),
                        content: Text(estado.error!),
                      ),
                    );
                },
              ),
              BlocListener<MultijugadorCubit, EstadoMultijugador>(
                // Al entrar o reconectarse no se repite el aviso viejo.
                listenWhen: (a, b) =>
                    a.sala != null &&
                    b.sala?.ultimoMovimiento != null &&
                    a.sala?.ultimoMovimiento != b.sala?.ultimoMovimiento,
                listener: (context, estado) =>
                    _avisarZona(context, estado.sala!),
              ),
            ],
            child: BlocBuilder<MultijugadorCubit, EstadoMultijugador>(
              builder: (context, estado) {
                final sala = estado.sala;
                return Column(
                  children: [
                    if (estado.reconectando && sala != null)
                      const _BannerReconectando(),
                    Expanded(
                      child: switch (sala) {
                        null => _Conectando(estado: estado),
                        SalaRemota(enLobby: true) => VistaLobby(estado: estado),
                        SalaRemota(enNumeros: true) => VistaNumerosMulti(
                          estado: estado,
                        ),
                        SalaRemota(terminada: true) => VistaResultado(
                          estado: estado,
                        ),
                        _ => VistaPartidaMulti(estado: estado),
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerReconectando extends StatelessWidget {
  const _BannerReconectando();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('banner-reconectando'),
      width: double.infinity,
      color: const Color(0xFFF5B83D),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.black87,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reconectando… Tu lugar se guarda mientras vuelves.',
              style: TextStyle(color: Colors.black87, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Conectando extends StatelessWidget {
  final EstadoMultijugador estado;

  const _Conectando({required this.estado});

  @override
  Widget build(BuildContext context) {
    final texto = switch (estado.conexion) {
      EstadoConexion.reconectando => 'Reconectando…',
      EstadoConexion.conectado => 'Entrando a la sala…',
      _ => 'Conectando con el servidor…',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            texto,
            key: const Key('texto-conectando'),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.read<MultijugadorCubit>().salir(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
