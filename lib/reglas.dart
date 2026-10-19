import 'package:flutter/material.dart';

import 'juego.dart';
import 'tipo.dart';

const _panel = Color(0xFF1F2244);
const _dorado = Color(0xFFFFD166);

final List<(Tipo, String, int)> _colores = [
  (Tipo.rojo, 'Rojo', 2),
  (Tipo.azul, 'Azul', 2),
  (Tipo.verde, 'Verde', 2),
  (Tipo.morado, 'Morado', 2),
  (Tipo.amarillo, 'Amarillo', 1),
];

/// Abre la hoja con las reglas del juego.
Future<void> mostrarReglas(BuildContext context) {
  final alto = MediaQuery.of(context).size.height;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _panel,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alto * 0.85),
        child: const _ContenidoReglas(),
      ),
    ),
  );
}

class _ContenidoReglas extends StatelessWidget {
  const _ContenidoReglas();

  @override
  Widget build(BuildContext context) {
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
          const _Seccion('Regla de cada color'),
          for (final (tipo, nombre, zonas) in _colores)
            _FilaColor(tipo: tipo, nombre: nombre, zonas: zonas),
          const _Seccion('Puntos por zona'),
          const Text(
            'Una zona puntúa cuando se llena, según el orden en que los '
            'jugadores la llenan: 1.º, 2.º y 3.º. Después del tercero ya '
            'nadie puntúa. Una zona llena no se vacía, para que otros '
            'jugadores puedan llenarla después. Las dos zonas del mismo '
            'color son independientes y no se mezclan. Los amarillos son '
            'una sola zona repartida por todo el tablero. En modo '
            'individual siempre eres el primero en llenar.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 12),
          for (final (tipo, nombre, _) in _colores)
            _FilaPuntos(tipo: tipo, nombre: nombre),
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

class _FilaColor extends StatelessWidget {
  final Tipo tipo;
  final String nombre;
  final int zonas;

  const _FilaColor({
    required this.tipo,
    required this.nombre,
    required this.zonas,
  });

  @override
  Widget build(BuildContext context) {
    final texto = tipo is TipoAmarillo ? Colors.black87 : Colors.white;
    final detalle = zonas == 1
        ? '1 zona de 5 casillas repartidas por el tablero'
        : '2 zonas';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tipo.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$nombre · $detalle',
            style: TextStyle(color: texto, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(tipo.descripcion, style: TextStyle(color: texto)),
        ],
      ),
    );
  }
}

class _FilaPuntos extends StatelessWidget {
  final Tipo tipo;
  final String nombre;

  const _FilaPuntos({required this.tipo, required this.nombre});

  @override
  Widget build(BuildContext context) {
    final p = puntosDe(tipo);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: tipo.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(nombre, style: const TextStyle(color: Colors.white)),
          ),
          Expanded(
            child: Text(
              '1.º ${p[0]}   2.º ${p[1]}   3.º ${p[2]}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}