import 'package:flutter/painting.dart';
import 'package:reglas_brilliant/reglas_brilliant.dart';

// Las reglas (tipos, mapas, tablero y puntaje) están en el paquete
// reglas_brilliant. Este archivo las reexporta y agrega lo que es solo de
// la app: el color de cada tipo.
export 'package:reglas_brilliant/reglas_brilliant.dart';

/// Color de cada tipo de zona en pantalla.
extension ColorDeTipo on Tipo {
  Color get color => switch (this) {
        TipoRojo() => const Color(0xFFE5484D),
        TipoAmarillo() => const Color(0xFFF5B83D),
        TipoVerde() => const Color(0xFF3FB67A),
        TipoAzul() => const Color(0xFF3E9BF0),
        TipoMorado() => const Color(0xFF8E5CF0),
        TipoBlanco() => const Color(0xFFD9DCE3),
        TipoNaranja() => const Color(0xFFF28C28),
      };
}
