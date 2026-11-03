import 'package:flutter/material.dart';
// ScrollCacheExtent no viene en material.dart en esta versión de Flutter.
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import 'auth_repository.dart';
import 'juego.dart';
import 'numeros_iniciales_screen.dart';
import 'reglas.dart';

const _fondo = Color(0xFF14162B);
const _panel = Color(0xFF1F2244);
const _dorado = Color(0xFFFFD166);

class BuscarPartidaScreen extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback alCerrarSesion;

  const BuscarPartidaScreen({
    super.key,
    required this.usuario,
    required this.alCerrarSesion,
  });

  @override
  State<BuscarPartidaScreen> createState() => _BuscarPartidaScreenState();
}

class _BuscarPartidaScreenState extends State<BuscarPartidaScreen> {
  Nivel _mapa = nivelesDisponibles.first;

  void _buscar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NumerosInicialesScreen(nivel: _mapa)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'BRILLIANT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => mostrarReglas(context, _mapa),
                        tooltip: 'Reglas',
                        icon: const Icon(
                          Icons.help_outline_rounded,
                          color: Colors.white70,
                        ),
                      ),
                      IconButton(
                        onPressed: widget.alCerrarSesion,
                        tooltip: 'Cerrar sesión',
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Hola, ${widget.usuario.nombre}',
                    style: const TextStyle(color: _dorado, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Buscar partida',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Elige el mapa en el que quieres jugar',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.05,
                      scrollCacheExtent: const ScrollCacheExtent.pixels(1000),
                      children: [
                        for (final mapa in nivelesDisponibles)
                          _TarjetaMapa(
                            mapa: mapa,
                            seleccionado: mapa.numero == _mapa.numero,
                            alTocar: () => setState(() => _mapa = mapa),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mapa ${_mapa.numero} · ${_mapa.estructura.zonas.length} zonas',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _buscar,
                      child: const Text('Buscar partida'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Por ahora juegas solo. El modo en línea llegará pronto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaMapa extends StatelessWidget {
  final Nivel mapa;
  final bool seleccionado;
  final VoidCallback alTocar;

  const _TarjetaMapa({
    required this.mapa,
    required this.seleccionado,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        key: Key('mapa-${mapa.numero}'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionado ? _dorado : Colors.transparent,
            width: 3,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _MiniTablero(mapa: mapa),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mapa ${mapa.numero}',
              style: TextStyle(
                color: seleccionado ? _dorado : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista previa del mapa; las estrellas se ven como puntos dorados.
class _MiniTablero extends StatelessWidget {
  final Nivel mapa;

  const _MiniTablero({required this.mapa});

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