# reglas_brilliant

Las reglas de Brilliant en **Dart puro** (sin Flutter). Las usan la app y el
servidor, por ruta, para que los dos apliquen exactamente las mismas reglas.

| Archivo | Qué tiene |
|---|---|
| `lib/src/tipo.dart` | Tipos de zona, su regla de colocación (`esPosibleAgregar`) y su descripción. Los colores los pone la app. |
| `lib/src/mapas.dart` | Los 4 mapas: layouts, estrellas, zonas (`EstructuraTablero`) y puntos. |
| `lib/src/juego.dart` | `Juego`: el tablero de un jugador, sus jugadas posibles y la colocación. |
| `lib/src/puntaje.dart` | Puntaje por orden de llenado de cada zona. |
| `lib/src/numeros_iniciales.dart` | Validación de los 6 números iniciales y una elección válida al azar. |

## Pruebas

```bash
dart pub get
dart analyze
dart test
```
