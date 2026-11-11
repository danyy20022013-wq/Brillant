import 'package:flutter/material.dart';

import 'auth_repository.dart';
import 'eliminar_cuenta_dialogo.dart';
import 'multijugador/dialogos_sala.dart';
import 'multijugador/multijugador_cubit.dart';
import 'multijugador/pantalla_sala.dart';
import 'numeros_iniciales_screen.dart';
import 'piezas_juego.dart';
import 'reglas.dart';
import 'tipo.dart';

const _fondo = Color(0xFF14162B);
const _panel = Color(0xFF1F2244);
const _dorado = Color(0xFFFFD166);

class BuscarPartidaScreen extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback alCerrarSesion;

  /// Si se indica, aparece la opción "Eliminar cuenta" (separada de
  /// "Cerrar sesión").
  final EliminarCuenta? alEliminarCuenta;

  /// Si se indica, aparecen "Crear sala" y "Unirme con código" para jugar
  /// en línea.
  final AbrirSala? abrirSala;

  const BuscarPartidaScreen({
    super.key,
    required this.usuario,
    required this.alCerrarSesion,
    this.alEliminarCuenta,
    this.abrirSala,
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

  void _abrir(AbrirSala abrir, AccionInicial accion) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaSala(crearCubit: () => abrir(accion)),
      ),
    );
  }

  Future<void> _crearSala(AbrirSala abrir) async {
    final maximo = await mostrarDialogoCrearSala(context, _mapa);
    if (maximo == null || !mounted) return;
    _abrir(abrir, AccionInicial.crear(mapa: _mapa.numero, maximo: maximo));
  }

  Future<void> _unirse(AbrirSala abrir) async {
    final codigo = await mostrarDialogoUnirse(context);
    if (codigo == null || !mounted) return;
    _abrir(abrir, AccionInicial.unirse(codigo));
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
                      cacheExtent: 1000,
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
                  const SizedBox(height: 8),
                  if (widget.abrirSala case final abrir?)
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('boton-crear-sala'),
                              onPressed: () => _crearSala(abrir),
                              icon: const Icon(Icons.group_add_rounded, size: 18),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Crear sala'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('boton-unirse'),
                              onPressed: () => _unirse(abrir),
                              icon: const Icon(Icons.login_rounded, size: 18),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Unirme con código'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Text(
                      'Juego en línea no disponible sin servidor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  if (widget.alEliminarCuenta case final eliminar?)
                    Center(
                      child: TextButton.icon(
                        key: const Key('opcion-eliminar-cuenta'),
                        onPressed: () =>
                            mostrarDialogoEliminarCuenta(context, eliminar),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF8A8A),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          size: 18,
                        ),
                        label: const Text('Eliminar cuenta'),
                      ),
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
                  child: MiniTablero(mapa: mapa),
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
