import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'juego_cubit.dart';
import 'piezas_juego.dart';
import 'reglas.dart';
import 'tipo.dart';

export 'piezas_juego.dart' show duracionAvisoZona, duracionGiroDados;

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

/// Muestra el aviso flotante de [zona] completada. Va sobre el panel de
/// zonas (no tapa el tablero, los dados ni los botones) y se va solo.
void mostrarAvisoZona(BuildContext context, ZonaCompletada zona) {
  mostrarAvisoFlotante(
    context,
    clave: Key('aviso-zona-${zona.turno}'),
    titulo: zona.puntua ? '+${zona.puntos} puntos' : 'Ya no puntúa',
    detalle: '${zona.nombre} completada',
    color: zona.tipo.color,
    destacado: zona.puntua,
  );
}

class _VistaJuego extends StatefulWidget {
  const _VistaJuego();

  @override
  State<_VistaJuego> createState() => _VistaJuegoState();
}

class _VistaJuegoState extends State<_VistaJuego>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giro =
      AnimationController(vsync: this, duration: duracionGiroDados)
        // Al empezar y al terminar se redibuja para bloquear/desbloquear.
        ..addStatusListener((_) => setState(() {}));

  bool get _girando => _giro.isAnimating;

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  /// El cubit decide los valores; la animación solo los muestra.
  void _tirar() {
    context.read<JuegoCubit>().tirarDados();
    _giro.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: SafeArea(
        child: BlocListener<JuegoCubit, JuegoEstado>(
          // Cada zona completada genera un aviso; el ScaffoldMessenger los
          // encola, así que varios seguidos no se pisan.
          listenWhen: (anterior, actual) =>
              actual.zonaCompletada != null &&
              actual.zonaCompletada != anterior.zonaCompletada,
          listener: (context, estado) =>
              mostrarAvisoZona(context, estado.zonaCompletada!),
          child: _contenido(),
        ),
      ),
    );
  }

  Widget _contenido() {
    return BlocConsumer<JuegoCubit, JuegoEstado>(
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
                      _ZonaDados(estado: estado, giro: _giro),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _TableroJuego(
                          estado: estado,
                          bloqueado: _girando,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PanelZonas(estado: estado),
                      const SizedBox(height: 8),
                      _Botones(
                        estado: estado,
                        girando: _girando,
                        alTirar: _tirar,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
          onPressed: () => mostrarHistorial(context, estado),
          tooltip: 'Historial',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.history_rounded, color: Colors.white70),
        ),
        IconButton(
          onPressed: () => mostrarReglas(context, estado.nivel),
          tooltip: 'Reglas',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
        ),
      ],
    );
  }
}

/// Abre la lista de movimientos de la partida, del más reciente al más
/// antiguo.
Future<void> mostrarHistorial(BuildContext context, JuegoEstado estado) {
  final movimientos = estado.historial.reversed.toList();
  final alto = MediaQuery.sizeOf(context).height;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _panel,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alto * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historial',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (movimientos.isEmpty)
                const Text(
                  'Todavía no hay movimientos',
                  style: TextStyle(color: Colors.white70),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: movimientos.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white12, height: 12),
                    itemBuilder: (_, i) => Text(
                      movimientos[i].texto(individual: estado.esIndividual),
                      key: Key('movimiento-$i'),
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
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

  /// Avanza de 0 a 1 mientras los dados giran.
  final Animation<double> giro;

  const _ZonaDados({required this.estado, required this.giro});

  bool get _girando => giro.isAnimating;

  String get _instruccion {
    if (estado.terminado) return 'Partida terminada';
    if (_girando) return 'Tirando los dados…';
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
      return 'Con esa ancla no hay lugar, prueba con el otro dado';
    }
    return 'Coloca el ${estado.aColocar} junto a un ${estado.ancla} '
        '(casillas iluminadas)';
  }

  String _etiqueta(int indice) {
    if (estado.indiceAncla == null) return '';
    return estado.indiceAncla == indice ? 'ANCLA' : 'A COLOCAR';
  }

  /// Mientras gira, cada dado muestra caras que cambian y rota; al final
  /// queda la cara con el valor que eligió el cubit.
  Widget _dado(BuildContext context, int indice, int? valor) {
    final cubit = context.read<JuegoCubit>();
    final tocable = !_girando && !estado.terminado && estado.hayDados;

    return AnimatedBuilder(
      animation: giro,
      builder: (context, _) {
        final girando = giro.isAnimating;
        final cara = girando
            ? caraEnGiro(giro.value, indice)
            : valor;
        return CaraDado(
          key: Key('dado-$indice'),
          valor: cara,
          angulo: girando ? giro.value * 4 * pi : 0,
          etiqueta: girando ? '' : _etiqueta(indice),
          esAncla: !girando && estado.indiceAncla == indice,
          onTap: tocable ? () => cubit.elegirAncla(indice) : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          _dado(context, 0, estado.dado1),
          const SizedBox(width: 10),
          _dado(context, 1, estado.dado2),
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

/// El tablero del jugador del turno, con las casillas iluminadas.
class _TableroJuego extends StatelessWidget {
  final JuegoEstado estado;

  /// true mientras giran los dados: ninguna casilla se puede tocar.
  final bool bloqueado;

  const _TableroJuego({required this.estado, this.bloqueado = false});

  @override
  Widget build(BuildContext context) {
    return TableroPartida(
      mapa: estado.nivel,
      tablero: estado.juego.tablero,
      resaltadas: bloqueado ? const {} : estado.jugadasResaltadas,
      ancla: estado.ancla,
      sugerido: estado.aColocar,
      alTocar: (f, col) => context.read<JuegoCubit>().colocar(f, col),
    );
  }
}

/// Las zonas del mapa en filas de chips, con su próximo puntaje.
class _PanelZonas extends StatelessWidget {
  final JuegoEstado estado;

  const _PanelZonas({required this.estado});

  @override
  Widget build(BuildContext context) {
    return PanelZonas(
      mapa: estado.nivel,
      ordenZonas: estado.ordenZonas,
      individual: estado.esIndividual,
      etiqueta: (p) => 'J${p + 1}',
    );
  }
}

class _Botones extends StatelessWidget {
  final JuegoEstado estado;
  final bool girando;
  final VoidCallback alTirar;

  const _Botones({
    required this.estado,
    required this.girando,
    required this.alTirar,
  });

  /// Pide confirmación antes de saltar el turno; avisa si aún hay jugadas.
  Future<void> _confirmarSaltar(BuildContext context) async {
    final cubit = context.read<JuegoCubit>();
    final aviso = estado.hayJugadas
        ? 'Todavía tienes jugadas posibles. ¿Quieres saltar el turno?'
        : 'No tienes jugadas posibles con estos dados.';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Saltar el turno?'),
        content: Text(aviso),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Saltar'),
          ),
        ],
      ),
    );
    if (confirmado ?? false) cubit.pasarTurno();
  }

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
      accion = alTirar;
    } else {
      texto = 'Saltar turno';
      accion = girando ? null : () => _confirmarSaltar(context);
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