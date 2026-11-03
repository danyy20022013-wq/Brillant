import 'package:flutter/material.dart';

import 'juego.dart';
import 'tipo.dart';

const _panel = Color(0xFF1F2244);
const _dorado = Color(0xFFFFD166);

/// Abre la hoja con las reglas del juego para el [mapa]: cómo se juega y,
/// por cada zona del mapa, su color, nombre, regla y puntos.
Future<void> mostrarReglas(BuildContext context, Nivel mapa) {
  final alto = MediaQuery.of(context).size.height;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _panel,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alto * 0.85),
        child: _ContenidoReglas(mapa: mapa),
      ),
    ),
  );
}

/// Sobre amarillo y blanco el texto va oscuro para que se lea.
bool _fondoClaro(Tipo tipo) => tipo is TipoAmarillo || tipo is TipoBlanco;

class _ContenidoReglas extends StatelessWidget {
  final Nivel mapa;

  const _ContenidoReglas({required this.mapa});

  @override
  Widget build(BuildContext context) {
    final zonas = mapa.estructura.zonas;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reglas del juego',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Mapa ${mapa.numero} · ${zonas.length} zonas',
            style: const TextStyle(color: Colors.white54),
          ),
          const _Seccion('Cómo se juega'),
          const _Paso(
            '1',
            'Elige tus 6 números iniciales (del 1 al 6, sin repetir) '
                'en las casillas con ⭐.',
          ),
          const _Paso('2', 'En tu turno, tira los dos dados.'),
          const _Paso(
            '3',
            'Toca un dado para elegirlo como ANCLA: es el número que ya '
                'está en el tablero.',
          ),
          const _Paso(
            '4',
            'El otro número lo colocas en una casilla vacía pegada arriba, '
                'abajo, a la izquierda o a la derecha de un ancla (nunca en '
                'diagonal). Las casillas posibles se iluminan.',
          ),
          const _Paso(
            '5',
            'Si no hay ninguna jugada posible, pasa el turno.',
          ),
          const _Paso(
            '6',
            'La partida termina cuando el tablero está lleno o cuando '
                'presionas Terminar.',
          ),
          const _Seccion('Puntos por zona'),
          const Text(
            'Una zona puntúa cuando se llena, según el orden en que los '
            'jugadores la llenan: 1.º, 2.º y 3.º. Después del tercero ya '
            'nadie puntúa. Una zona llena no se vacía, para que otros '
            'jugadores puedan llenarla después. Las zonas del mismo color '
            'son independientes y no se mezclan. Algunos colores forman '
            'una sola zona aunque sus casillas estén separadas. En modo '
            'individual siempre eres el primero en llenar.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
          _Seccion('Zonas del mapa ${mapa.numero}'),
          for (final zona in zonas) _FilaZona(zona: zona),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String texto;

  const _Seccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          color: _dorado,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  final String numero;
  final String texto;

  const _Paso(this.numero, this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              numero,
              style: const TextStyle(
                color: _dorado,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: Colors.white70, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una zona del mapa: nombre, casillas, regla y puntos, sobre su color.
class _FilaZona extends StatelessWidget {
  final ZonaDef zona;

  const _FilaZona({required this.zona});

  @override
  Widget build(BuildContext context) {
    final texto = _fondoClaro(zona.tipo) ? Colors.black87 : Colors.white;
    final p = zona.puntos;
    final casillas = zona.celdas.length;

    return Container(
      key: Key('regla-${zona.nombre}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: zona.tipo.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${zona.nombre} · $casillas casillas',
            style: TextStyle(color: texto, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(zona.tipo.descripcion, style: TextStyle(color: texto)),
          const SizedBox(height: 2),
          Text(
            '1.º ${p[0]}   2.º ${p[1]}   3.º ${p[2]}',
            style: TextStyle(color: texto, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
