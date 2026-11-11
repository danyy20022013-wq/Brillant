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
- Dependencias: `bloc`, `flutter_bloc`, `equatable`, `http`,
  `flutter_secure_storage`, `web_socket_channel` (multijugador) y el paquete
  local `reglas_brilliant`.
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

### Prueba de integración del multijugador (lenta)

`test/integracion_multijugador_test.dart` levanta el **servidor real** en un
puerto libre, con una base de datos temporal y una clave generada solo para
la prueba, y conecta dos clientes: crean la sala, se unen, se marcan listos,
inician y juegan una jugada completa. Al terminar cierra el servidor y borra
la base temporal.

Tiene la etiqueta `integracion` y con `flutter test` normal aparece como
omitida. Para correrla:

```powershell
# PowerShell (Windows)
$env:BRILLIANT_INTEGRACION='1'; flutter test --tags integracion
```

```bash
# bash
BRILLIANT_INTEGRACION=1 flutter test --tags integracion
```

Usa el Dart que trae Flutter (`FLUTTER_ROOT`). El servidor necesita **Dart
3.11 o superior**; si tu Flutter trae un Dart más viejo, indica otro con
`BRILLIANT_DART` (por ejemplo `$env:BRILLIANT_DART='C:\ruta\a\dart.exe'`).
Antes hay que haber hecho `dart pub get` en `servidor/`. Como no hay un
`dart_test.yaml`, `flutter test` puede avisar que la etiqueta `integracion`
no está declarada; es solo un aviso.

## Jugar en línea con dos cuentas a la vez

1. **Servidor:** en `servidor/`, copia `.env.example` como `.env`, genera la
   clave (`dart run bin/generar_secreto.dart`) y arráncalo:

   ```bash
   cd servidor
   dart run bin/servidor.dart
   ```

2. **Dos copias de la app.** Cada copia necesita su propia sesión. En la web
   la sesión se guarda por navegador, así que dos pestañas del mismo Chrome
   comparten la cuenta. Usa una de estas combinaciones:
   - la app de **Windows** y la de **Chrome**:

     ```bash
     flutter run -d windows
     flutter run -d chrome
     ```

   - o la web servida una vez y abierta en **dos navegadores distintos** (o en
     una ventana normal y otra de incógnito):

     ```bash
     flutter run -d web-server --web-port 5000
     # abre http://localhost:5000 en Chrome y en Edge (o en incógnito)
     ```

   Si el servidor no está en `http://localhost:8080`, agrega
   `--dart-define=API_URL=http://tu-servidor:puerto`.
3. **Crea dos cuentas** (una en cada copia).
4. En la primera: elige el mapa, toca **Crear sala**, elige cuántos jugadores
   y toca **Copiar** (o **Compartir**, que copia un texto de invitación).
5. En la segunda: **Unirme con código** y escribe el código (se pasa a
   mayúsculas solo y no acepta 0, O, 1, I ni L).
6. Los dos tocan **Estoy listo** y el anfitrión toca **Iniciar partida**.

Para probar la reconexión, cierra una de las copias en plena partida y vuelve
a abrirla con la misma cuenta antes de 60 s: vuelve a su sala con el estado
completo.

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

**En línea** (desde Buscar partida, con *Crear sala* o *Unirme con código*):

1. **Lobby:** código grande con *Copiar* y *Compartir*, miniatura del mapa,
   jugadores con anfitrión, listo y desconectado, *Estoy listo*, *Iniciar
   partida* (solo el anfitrión, con 2 o más y todos listos) y *Salir* con
   confirmación.
2. **Números iniciales:** la misma pantalla de siempre, con el tiempo que
   queda. Al enviarlos se espera a los demás.
3. **Partida:** la misma tabla, dados (con su animación) y panel de zonas. El
   marcador muestra a todos con sus puntos, quién tiene el turno y si está
   conectado, desconectado (con cuenta regresiva), rendido o si abandonó. Fuera
   de turno los controles se desactivan. *Rendirse* explica que se queda
   último. Si se corta la conexión aparece "Reconectando…" y al volver se
   restaura todo.
4. **Resultado:** posiciones, puntos, empates y quién se rindió o abandonó,
   con *Volver al menú*.

La app **no inventa estado**: solo manda intenciones (colocar, saltar,
rendirse…) y muestra lo que difunde el servidor.

## Los 4 mapas

Cada mapa es un objeto `Nivel` (en el paquete `reglas_brilliant`, archivo
`paquetes/reglas_brilliant/lib/src/mapas.dart`) con:

- `layout`: la grilla de 7x7 con el tipo (color) de cada casilla;
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

| Carpeta | Qué tiene |
|---|---|
| `lib/`, `test/` | La app Flutter y sus pruebas. |
| `paquetes/reglas_brilliant/` | Las reglas del juego en **Dart puro** (sin Flutter): tipos de zona y su regla de colocación, los 4 mapas, el tablero de un jugador con sus jugadas posibles, el puntaje por orden de llenado y la validación de los números iniciales. La app y el servidor lo usan por ruta (`path:`), así que los dos aplican exactamente las mismas reglas. |
| `servidor/` | Servidor en Dart: cuentas y multijugador por WebSocket. Ver [`servidor/README.md`](servidor/README.md). |

Pruebas del paquete de reglas, desde su carpeta:

```bash
dart analyze
dart test
```

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
| `tipo.dart` | El **color** de cada tipo de zona (lo único de los tipos que es solo de la app). Reexporta el paquete `reglas_brilliant`. |
| `juego_cubit.dart` | Estado y lógica de la partida: dados, ancla, colocación, saltar turno, orden de llenado, puntos (calculados con el paquete), evento `ZonaCompletada` e historial. |
| `movimiento_registrado.dart` | Un movimiento del historial y su texto legible. |
| `numeros_iniciales_cubit.dart` | Estado de los números iniciales y su validación (repetidos y regla de la zona). |
| `numeros_iniciales_screen.dart` | Pantalla de números iniciales. |
| `juego_screen.dart` | Pantalla de la partida. |
| `reglas.dart` | Hoja de reglas, armada según el mapa. |
| `piezas_juego.dart` | Piezas visuales que comparten el modo individual y el en línea: dado, tablero, chips de zona, miniatura del mapa y aviso flotante. |
| `tablero.dart`, `zona.dart`, `tablero_cubit.dart` | Modelo anterior del tablero. La app ya no lo usa; se conserva con sus pruebas. |

### `lib/multijugador/`

| Archivo | Para qué sirve |
|---|---|
| `canal_ws.dart` | Interfaz del WebSocket (`CanalWs`) y la conexión real con `web_socket_channel`. |
| `conexion_multijugador.dart` | Token en el primer mensaje, latidos, estados (conectando, conectado, reconectando, caído), reconexión con espera creciente (1, 2, 4, 8 y 15 s, con tope de intentos), ids de acción y avisos en español. |
| `sala_remota.dart` | El estado de la sala tal como lo difunde el servidor. |
| `multijugador_cubit.dart` | Manda las intenciones y guarda lo último que confirmó el servidor. |
| `pantalla_sala.dart` | Elige la vista según la fase y muestra "Reconectando…" y los avisos. |
| `vista_lobby.dart`, `vista_numeros_multi.dart`, `vista_partida_multi.dart`, `vista_resultado.dart` | Las vistas de cada fase (incluye el marcador). |
| `dialogos_sala.dart`, `cuenta_regresiva.dart` | Diálogos de crear/unirse (con el formateador del código) y cuentas regresivas. |

### `test/`

Cada archivo prueba una parte de `lib/`:

- **Modelos y cubits:** `colores_tipo_test`, `juego_test`, `juego_cubit_test`,
  `juego_mapas_test`,
  `numeros_iniciales_cubit_test`, `zona_completada_test`, `historial_test`,
  `auth_test`, `validaciones_test`, y los del modelo anterior `tablero_test`,
  `zona_test` y `tablero_cubit_test`.
- **Pantallas:** `login_screen_test`, `buscar_partida_screen_test`,
  `numeros_iniciales_screen_test`, `numeros_iniciales_zona_test`,
  `juego_screen_test`, `mapas_pantalla_test`, `dados_saltar_turno_test`,
  `aviso_zona_test`, `historial_pantalla_test` y `reglas_test`.
- **Recorrido completo:** `widget_test` (registro, elegir mapa, números, jugar
  y volver a Buscar partida).
- **Multijugador:** `multijugador_cubit_test` (conexión, reconexión, avisos e
  ids) y `multijugador_pantallas_test` (lobby, partida, marcador, resultado y
  los 3 tamaños), con un servidor falso (`ayuda_multijugador.dart`); y
  `integracion_multijugador_test` contra el servidor real (ver arriba).

La mayoría de las pruebas de pantalla comprueban que no haya desbordes en
320x568, 360x640 y 411x891.

Las pruebas de las reglas (tipos, mapas, tablero de un jugador, puntaje y
números iniciales) están en `paquetes/reglas_brilliant/test/`.

## Estado actual

- Se juega en **modo individual** (sin cambios) y **en línea** de 2 a 4
  jugadores contra el servidor.
- Las cuentas están en el **servidor** (`ApiAuthRepository`); la versión en
  memoria queda solo para las pruebas.
- El protocolo del multijugador está en
  [`servidor/README.md`](servidor/README.md).

## Limitaciones (honestas)

- **Las salas viven en memoria del servidor.** Si se reinicia, todas las
  salas y partidas en curso se pierden; la app avisa "Esa sala ya no existe"
  y vuelve al menú.
- **Un solo servidor.** Salas, conexiones y límites están en la memoria de
  un único proceso: no se puede repartir la carga entre varias instancias sin
  un almacén compartido (por ejemplo Redis).
- **El límite de intentos también está en memoria** (inicio de sesión,
  registro y unirse a salas): se reinicia al reiniciar el servidor.
- **WebSocket sin cifrar en desarrollo** (`ws://`). En un despliegue real
  hay que ponerlo detrás de un proxy con HTTPS para usar `wss://`.
- **"Compartir" copia la invitación** al portapapeles: la app no abre el menú
  de compartir del sistema.
- **Tirar los dados no le pide nada al servidor:** el servidor ya los tiró
  al empezar el turno; el botón solo los muestra con la animación.
- **La cuenta regresiva de un jugador desconectado es aproximada:** el
  servidor no manda cuándo vence su plazo, así que la app cuenta 60 s (el
  valor por defecto de `SEGUNDOS_RECONEXION`) desde que lo vio caerse.
- **La sesión dura una hora** (el token): si vence en plena partida, la app
  no puede reconectarse y pide volver a iniciar sesión.

## Pendiente

- Que el servidor mande cuándo vence el plazo de reconexión de cada jugador,
  para que la cuenta regresiva sea exacta.
- Compartir con el menú del sistema.
