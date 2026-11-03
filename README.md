# Brilliant

Juego de tablero hecho en Flutter y Dart para un proyecto de la universidad.
Cada jugador tiene un tablero de 7x7 casillas de colores. En cada turno tira
dos dados y coloca números en el tablero respetando la regla del color de cada
zona. Llenar zonas da puntos según el orden en que se llenan.

## Cómo se juega

1. **Números iniciales.** El tablero tiene 6 casillas con estrella. Pones en
   ellas los números del 1 al 6, sin repetir. Cada número debe cumplir la regla
   de la zona de su estrella (por ejemplo, en el mapa 4 la estrella naranja de
   arriba solo acepta 4, 5 o 6).
2. **Turno.** Se tiran 2 dados. Uno es el **ancla**: un número que ya está en el
   tablero. El otro se coloca en una casilla vacía pegada al ancla (arriba,
   abajo, izquierda o derecha, nunca en diagonal) y que respete la regla de su
   zona. Las casillas posibles se iluminan.
3. **Saltar turno.** Con los dados tirados puedes saltar el turno. La app pide
   confirmación y avisa si todavía tenías jugadas posibles.
4. **Fin.** La partida termina cuando el tablero se llena o al tocar
   *Terminar*.

### Reglas por color

| Color | Regla |
|---|---|
| Rojo | Todos los números distintos |
| Amarillo | Todos los números distintos |
| Verde | Cualquier número |
| Azul | Todos los números iguales |
| Blanco | Todos los números iguales |
| Morado | Máximo dos números diferentes por zona |
| Naranja 4-6 | Solo números del 4 al 6 (se pueden repetir) |
| Naranja 1-3 | Solo números del 1 al 3 (se pueden repetir) |

### Puntos

- Una zona puntúa cuando se llena. Ganan puntos los 3 primeros jugadores que
  la llenan (1.º, 2.º y 3.º); del 4.º en adelante ya no puntúa.
- Una zona llena no se vacía, y cada zona lleva su propio orden aunque sea del
  mismo color que otra.
- En modo individual siempre eres el primero.
- Los puntos de cada zona dependen del mapa (ver más abajo).

## Requisitos

- Flutter con Dart 3.9 o superior (`sdk: ^3.9.0` en `pubspec.yaml`).
- Dependencias: `bloc`, `flutter_bloc` y `equatable`.
- El proyecto tiene configuradas las plataformas **web** (`web/`) y
  **Windows** (`windows/`).

## Ejecutar la app

```bash
flutter pub get
flutter run -d chrome
```

## Análisis y pruebas

```bash
flutter analyze
flutter test
```

Para medir la cobertura: `flutter test --coverage` (genera `coverage/`, que
está ignorada por git).

## Flujo de la app

1. **Inicio de sesión** (`LoginScreen`): correo y contraseña. Desde aquí se
   puede ir a **Crear cuenta** (`RegistroScreen`), que pide nombre de usuario,
   correo, contraseña y su confirmación.
2. **Buscar partida** (`BuscarPartidaScreen`): saluda al usuario y muestra una
   tarjeta con la miniatura de cada uno de los 4 mapas. Se elige uno y se toca
   *Buscar partida*. Desde aquí también se abren las reglas y se cierra sesión.
3. **Números iniciales** (`NumerosInicialesScreen`): se tocan las estrellas y
   se elige su número. El selector muestra la regla de la zona y deja
   deshabilitados los números que no la cumplen. *Inicio* se habilita con los 6
   números completos, sin repetir y válidos.
4. **Partida** (`JuegoScreen`):
   - dados con una animación corta de giro;
   - elegir el ancla y colocar en una casilla iluminada;
   - *Saltar turno* con confirmación;
   - aviso flotante al completar una zona ("+7 puntos / Azul 1 completada");
   - panel de zonas con los puntos que da cada una;
   - botón **Historial** con los movimientos de la partida;
   - botón **?** con las reglas del mapa que se juega.

   Al terminar, *Nueva partida* vuelve a Buscar partida.

## Los 4 mapas

Cada mapa es un objeto `Nivel` (en `lib/juego.dart`) con:

- `layout`: la grilla de 7x7 con el tipo (color) de cada casilla, definida en
  `lib/tablero_layout.dart`;
- `estrellas`: las 6 casillas con estrella, en orden de lectura;
- `zonaUnica`: los colores que forman **una sola zona** aunque sus casillas
  estén separadas;
- `puntos`: los puntos (1.º, 2.º, 3.º) de cada color en ese mapa.

Las zonas se arman una sola vez por mapa (`EstructuraTablero.desdeLayout`): las
casillas vecinas (arriba, abajo, izquierda, derecha) del mismo color forman una
zona, y los colores de `zonaUnica` se juntan en una. Las zonas se nombran en
orden de lectura: "Rojo 1", "Rojo 2"... si hay varias del mismo color, o solo
"Verde" si hay una.

| Mapa | Zonas | Zona única | Puntos (1.º / 2.º / 3.º) |
|---|---|---|---|
| 1 | 9 | amarillo | azul 7/5/3, verde 4/3/2, rojo 6/4/2, morado 6/4/2, amarillo 8/6/4 |
| 2 | 10 | amarillo y blanco | azul 7/5/3, verde 4/3/2, rojo 6/4/2, morado 6/4/2, amarillo 6/4/2, blanco 3/2/1 |
| 3 | 10 | blanco | azul 7/5/3, verde 6/5/4, rojo 6/4/2, morado 7/5/3, amarillo 7/5/3, blanco 8/6/4 |
| 4 | 10 | amarillo, azul y verde | azul 8/6/4, verde 3/2/1, rojo 6/4/2, morado 7/5/3, amarillo 8/6/4, naranja 6/4/3 |

La hoja de reglas, el panel de zonas y los puntos de la partida se calculan a
partir de estos datos; nada se escribe a mano por mapa.

## Estructura del proyecto

### `lib/`

| Archivo | Para qué sirve |
|---|---|
| `main.dart` | Arranca la app. Muestra el inicio de sesión o, con sesión, Buscar partida. |
| `auth_repository.dart` | `Usuario`, `AuthException`, la interfaz `AuthRepository` y su versión en memoria `InMemoryAuthRepository`. |
| `auth_cubit.dart` | Estado de la sesión: iniciar sesión, registrarse, cerrar sesión y errores. |
| `validaciones.dart` | Validación de nombre, correo, contraseña y confirmación. |
| `campos_auth.dart` | Estilo común de los campos y el campo de contraseña con botón para mostrarla. |
| `login_screen.dart` | Pantalla de inicio de sesión. |
| `registro_screen.dart` | Pantalla de registro. |
| `buscar_partida_screen.dart` | Selección de mapa y botón para empezar. |
| `tipo.dart` | Los tipos de zona (colores): color, regla escrita y regla de colocación (`esPosibleAgregar`). |
| `tablero_layout.dart` | Layouts y estrellas de los 4 mapas. |
| `juego.dart` | Modelo del juego: `ZonaDef`, `EstructuraTablero`, `Nivel`, los 4 mapas y `Juego` (el tablero de un jugador y sus jugadas posibles). |
| `juego_cubit.dart` | Estado y lógica de la partida: dados, ancla, colocación, saltar turno, orden de llenado, puntos, evento `ZonaCompletada` e historial. |
| `movimiento_registrado.dart` | Un movimiento del historial y su texto legible. |
| `numeros_iniciales_cubit.dart` | Estado de los números iniciales y su validación (repetidos y regla de la zona). |
| `numeros_iniciales_screen.dart` | Pantalla de números iniciales. |
| `juego_screen.dart` | Pantalla de la partida. |
| `reglas.dart` | Hoja de reglas, armada según el mapa. |
| `tablero.dart`, `zona.dart`, `tablero_cubit.dart` | Modelo anterior del tablero. La app ya no lo usa; se conserva con sus pruebas. |

### `test/`

Cada archivo prueba una parte de `lib/`:

- **Modelos y cubits:** `tipo_test`, `nivel_test`, `tablero_layout_test`
  (mapa 1), `juego_test`, `juego_cubit_test`, `juego_mapas_test`,
  `numeros_iniciales_cubit_test`, `zona_completada_test`, `historial_test`,
  `auth_test`, `validaciones_test`, y los del modelo anterior `tablero_test`,
  `zona_test` y `tablero_cubit_test`.
- **Pantallas:** `login_screen_test`, `buscar_partida_screen_test`,
  `numeros_iniciales_screen_test`, `numeros_iniciales_zona_test`,
  `juego_screen_test`, `mapas_pantalla_test`, `dados_saltar_turno_test`,
  `aviso_zona_test`, `historial_pantalla_test` y `reglas_test`.
- **Recorrido completo:** `widget_test` (registro, elegir mapa, números, jugar
  y volver a Buscar partida).

La mayoría de las pruebas de pantalla comprueban que no haya desbordes en
320x568, 360x640 y 411x891.

## Estado actual

- Se juega en **modo individual**. La lógica de la partida (`JuegoCubit`) ya
  admite varios jugadores, pero la app todavía no ofrece cómo elegirlos.
- Las **cuentas viven solo en memoria** (`InMemoryAuthRepository`): se pierden
  al cerrar la app y la contraseña no se cifra. Es solo para desarrollo.

## Pendiente

- Servidor con autenticación segura, que reemplace a `InMemoryAuthRepository`
  detrás de la interfaz `AuthRepository`.
- Crear y borrar cuenta en el servidor.
- Modo en línea con varios jugadores.
